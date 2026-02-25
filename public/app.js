const sourceIsoEl = document.getElementById('sourceIso');
const outputIsoEl = document.getElementById('outputIso');
const workingDirectoryEl = document.getElementById('workingDirectory');
const programsEl = document.getElementById('programs');
const logsEl = document.getElementById('logs');
const badgeEl = document.getElementById('statusBadge');
const buildBtnEl = document.getElementById('buildBtn');
const selectAllEl = document.getElementById('selectAll');
const clearAllEl = document.getElementById('clearAll');
const addProgramBtnEl = document.getElementById('addProgramBtn');
const catalogActionLogEl = document.getElementById('catalogActionLog');
const newProgramKeyEl = document.getElementById('newProgramKey');
const newProgramDisplayNameEl = document.getElementById('newProgramDisplayName');
const newProgramPackageEl = document.getElementById('newProgramPackage');

let currentJobId = null;
let pollTimer = null;

function setBadge(status) {
  badgeEl.className = `badge ${status}`;
  badgeEl.textContent = status.charAt(0).toUpperCase() + status.slice(1);
}

function checkedProgramKeys() {
  return Array.from(document.querySelectorAll('.program-checkbox:checked')).map(el => el.value);
}

function renderPrograms(catalog) {
  const entries = Object.entries(catalog).sort((a, b) => a[0].localeCompare(b[0]));
  programsEl.innerHTML = entries.map(([key, value]) => `
    <div class="program-item">
      <label>
        <input type="checkbox" class="program-checkbox" value="${key}" />
        <span>
          <strong>${value.displayName}</strong><br />
          <span class="program-key">${key} • ${value.package}</span>
        </span>
      </label>
    </div>
  `).join('');
}

async function loadCatalog() {
  const response = await fetch('/api/catalog');
  if (!response.ok) {
    throw new Error('Unable to load program catalog.');
  }

  const data = await response.json();
  renderPrograms(data);
}

async function addProgram() {
  const key = newProgramKeyEl.value.trim();
  const displayName = newProgramDisplayNameEl.value.trim();
  const packageName = newProgramPackageEl.value.trim();

  if (!key || !displayName || !packageName) {
    catalogActionLogEl.textContent = 'Please fill key, display name, and package.';
    return;
  }

  addProgramBtnEl.disabled = true;
  try {
    const response = await fetch('/api/catalog', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key, displayName, package: packageName, source: 'choco' })
    });

    const result = await response.json();
    if (!response.ok) {
      catalogActionLogEl.textContent = `Failed to add program: ${result.error || 'Unknown error'}`;
      return;
    }

    catalogActionLogEl.textContent = `Program added: ${result.key} (${result.program.package})`;
    newProgramKeyEl.value = '';
    newProgramDisplayNameEl.value = '';
    newProgramPackageEl.value = '';
    await loadCatalog();
  } catch (error) {
    catalogActionLogEl.textContent = `Failed to add program: ${error.message}`;
  } finally {
    addProgramBtnEl.disabled = false;
  }
}

async function pollJob() {
  if (!currentJobId) {
    return;
  }

  const response = await fetch(`/api/build/${currentJobId}`);
  if (!response.ok) {
    logsEl.textContent = 'Build job not found.';
    clearInterval(pollTimer);
    setBadge('failed');
    return;
  }

  const job = await response.json();
  setBadge(job.status);
  logsEl.textContent = (job.logs || []).join('');
  logsEl.scrollTop = logsEl.scrollHeight;

  if (job.status === 'completed' || job.status === 'failed') {
    clearInterval(pollTimer);
    buildBtnEl.disabled = false;
  }
}

async function startBuild() {
  const programs = checkedProgramKeys();
  if (!sourceIsoEl.value.trim() || !outputIsoEl.value.trim() || programs.length === 0) {
    alert('Please enter source path, output path, and select at least one program.');
    return;
  }

  buildBtnEl.disabled = true;
  logsEl.textContent = 'Starting build...\n';
  setBadge('running');

  const response = await fetch('/api/build', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sourceIso: sourceIsoEl.value.trim(),
      outputIso: outputIsoEl.value.trim(),
      workingDirectory: workingDirectoryEl.value.trim(),
      programs
    })
  });

  const result = await response.json();
  if (!response.ok) {
    logsEl.textContent = `Failed to start build: ${result.error || 'Unknown error'}`;
    setBadge('failed');
    buildBtnEl.disabled = false;
    return;
  }

  currentJobId = result.id;
  pollTimer = setInterval(pollJob, 2000);
  await pollJob();
}

buildBtnEl.addEventListener('click', () => startBuild().catch(err => {
  logsEl.textContent = err.message;
  setBadge('failed');
  buildBtnEl.disabled = false;
}));

addProgramBtnEl.addEventListener('click', () => addProgram().catch(err => {
  catalogActionLogEl.textContent = err.message;
}));

selectAllEl.addEventListener('click', () => {
  document.querySelectorAll('.program-checkbox').forEach(el => { el.checked = true; });
});

clearAllEl.addEventListener('click', () => {
  document.querySelectorAll('.program-checkbox').forEach(el => { el.checked = false; });
});

loadCatalog().catch(error => {
  logsEl.textContent = error.message;
  setBadge('failed');
});
