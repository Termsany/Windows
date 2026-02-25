const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto');

const PORT = process.env.PORT || 3000;
const ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'public');
const CATALOG_PATH = path.join(ROOT, 'programs', 'catalog.json');
const BUILDER_SCRIPT = path.join(ROOT, 'scripts', 'Build-CustomWindowsIso.ps1');

const jobs = new Map();

function sendJson(res, statusCode, data) {
  const body = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', chunk => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        reject(new Error('Request body too large'));
      }
    });
    req.on('end', () => {
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error('Invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}

function serveStatic(req, res) {
  const relativePath = req.url === '/' ? '/index.html' : req.url;
  const safePath = path.normalize(relativePath).replace(/^([.][.][/\\])+/, '');
  const filePath = path.join(PUBLIC_DIR, safePath);

  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    const ext = path.extname(filePath);
    const contentTypeMap = {
      '.html': 'text/html; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.js': 'application/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8'
    };

    res.writeHead(200, { 'Content-Type': contentTypeMap[ext] || 'application/octet-stream' });
    res.end(data);
  });
}

function readCatalog() {
  const text = fs.readFileSync(CATALOG_PATH, 'utf8');
  return JSON.parse(text);
}

function writeCatalog(catalog) {
  fs.writeFileSync(CATALOG_PATH, `${JSON.stringify(catalog, null, 2)}\n`, 'utf8');
}

function sanitizeKey(rawKey) {
  return String(rawKey || '').trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
}

function startBuildJob({ sourceIso, outputIso, workingDirectory, programs }) {
  const id = randomUUID();
  const job = {
    id,
    status: 'running',
    startedAt: new Date().toISOString(),
    endedAt: null,
    command: '',
    logs: [],
    exitCode: null
  };
  jobs.set(id, job);

  if (process.platform !== 'win32') {
    job.status = 'failed';
    job.endedAt = new Date().toISOString();
    job.exitCode = 1;
    job.logs.push('Build execution is supported only on Windows (powershell.exe required).');
    return job;
  }

  const args = [
    '-ExecutionPolicy', 'Bypass',
    '-File', BUILDER_SCRIPT,
    '-SourceIso', sourceIso,
    '-OutputIso', outputIso,
    '-Programs',
    ...programs
  ];

  if (workingDirectory) {
    args.push('-WorkingDirectory', workingDirectory);
  }

  job.command = `powershell.exe ${args.join(' ')}`;

  const child = spawn('powershell.exe', args, { cwd: ROOT });

  child.stdout.on('data', chunk => {
    job.logs.push(chunk.toString());
  });

  child.stderr.on('data', chunk => {
    job.logs.push(chunk.toString());
  });

  child.on('error', err => {
    job.status = 'failed';
    job.endedAt = new Date().toISOString();
    job.exitCode = 1;
    job.logs.push(`Process error: ${err.message}`);
  });

  child.on('close', code => {
    job.exitCode = code;
    job.endedAt = new Date().toISOString();
    job.status = code === 0 ? 'completed' : 'failed';
  });

  return job;
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/api/catalog') {
      sendJson(res, 200, readCatalog());
      return;
    }

    if (req.method === 'POST' && req.url === '/api/catalog') {
      const body = await parseBody(req);
      const key = sanitizeKey(body.key);
      const displayName = String(body.displayName || '').trim();
      const source = String(body.source || 'choco').trim().toLowerCase();
      const packageName = String(body.package || '').trim();

      if (!key || !displayName || !packageName) {
        sendJson(res, 400, { error: 'key, displayName, and package are required.' });
        return;
      }

      if (source !== 'choco') {
        sendJson(res, 400, { error: 'Only source "choco" is supported right now.' });
        return;
      }

      const catalog = readCatalog();
      if (Object.prototype.hasOwnProperty.call(catalog, key)) {
        sendJson(res, 409, { error: `Program key already exists: ${key}` });
        return;
      }

      catalog[key] = {
        displayName,
        source,
        package: packageName
      };
      writeCatalog(catalog);

      sendJson(res, 201, { key, program: catalog[key] });
      return;
    }

    if (req.method === 'POST' && req.url === '/api/build') {
      const body = await parseBody(req);
      const { sourceIso, outputIso, workingDirectory = '', programs = [] } = body;

      if (!sourceIso || !outputIso || !Array.isArray(programs) || programs.length === 0) {
        sendJson(res, 400, { error: 'sourceIso, outputIso, and non-empty programs[] are required.' });
        return;
      }

      const catalog = readCatalog();
      const invalid = programs.filter(key => !Object.prototype.hasOwnProperty.call(catalog, key));
      if (invalid.length > 0) {
        sendJson(res, 400, { error: `Unknown program keys: ${invalid.join(', ')}` });
        return;
      }

      const job = startBuildJob({ sourceIso, outputIso, workingDirectory, programs });
      sendJson(res, 202, { id: job.id, status: job.status });
      return;
    }

    if (req.method === 'GET' && req.url.startsWith('/api/build/')) {
      const id = req.url.split('/').pop();
      const job = jobs.get(id);
      if (!job) {
        sendJson(res, 404, { error: 'Build job not found.' });
        return;
      }

      sendJson(res, 200, job);
      return;
    }

    if (req.method === 'GET') {
      serveStatic(req, res);
      return;
    }

    sendJson(res, 404, { error: 'Not found' });
  } catch (error) {
    sendJson(res, 500, { error: error.message });
  }
});

server.listen(PORT, () => {
  console.log(`ISO Dashboard running on http://localhost:${PORT}`);
});
