const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

function ensureJson(filePath) {
  JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function ensureXml(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  if (!content.includes('<unattend') || !content.includes('</unattend>')) {
    throw new Error(`Invalid XML structure in ${filePath}`);
  }
}

function ensureFile(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing file: ${filePath}`);
  }
}

function main() {
  ensureFile(path.join(root, 'src', 'server.js'));
  ensureFile(path.join(root, 'public', 'index.html'));
  ensureFile(path.join(root, 'public', 'app.js'));
  ensureFile(path.join(root, 'public', 'styles.css'));
  ensureJson(path.join(root, 'programs', 'catalog.json'));
  ensureXml(path.join(root, 'templates', 'Autounattend.xml'));
  console.log('Validation passed.');
}

main();
