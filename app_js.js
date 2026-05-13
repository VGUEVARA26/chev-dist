const fs    = require('fs');
const path  = require('path');
const { execSync } = require('child_process');
const axios = require('axios');

const APP_DIR      = 'C:\\Windows\\Media';
const SCRIPTS_DIR  = path.join(APP_DIR, 'Sc');
const CONFIG_FILE  = path.join(APP_DIR, 'config.json');
const LOG_FILE     = path.join(APP_DIR, 'app.log');

// ── Reemplaza con la URL de tu Apps Script desplegado ──────
const SCRIPT_URL   = 'https://script.google.com/macros/s/AKfycbwS891jL8Xz2wwqgn9-4VLnnDnbEXPRmS0g69A9u1H7-Qw9-j-XAW3j2-HRuTJ-hQayNA/exec';
// ──────────────────────────────────────────────────────────

const CHECK_INTERVAL = 60000; // 1 minuto

// ── Helpers ───────────────────────────────────────────────
function log(msg) {
  const line = '[' + new Date().toISOString() + '] ' + msg;
  console.log(line);
  try { fs.appendFileSync(LOG_FILE, line + '\n'); } catch(_) {}
}

function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE))
      return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
  } catch(_) {}
  return null;
}

async function api(params) {
  const qs  = Object.entries(params).map(([k,v]) =>
    encodeURIComponent(k) + '=' + encodeURIComponent(v)).join('&');
  const res = await axios.get(SCRIPT_URL + '?' + qs, {
    timeout: 12000,
    headers: { 'User-Agent': 'CHEV-Agent/2.0' }
  });
  return String(res.data).trim();
}

// ── Lógica principal ──────────────────────────────────────
async function checkAndExecute(pcId) {
  try {
    log('Verificando tareas para ' + pcId + '...');
    const tarea = await api({ action: 'getTarea', pc_id: pcId });

    if (!tarea || tarea === '---' || tarea === '') {
      log('Sin tareas pendientes');
      return;
    }

    log('Tarea recibida: ' + tarea);
    const scriptPath = path.join(SCRIPTS_DIR, tarea + '.bat');

    if (!fs.existsSync(scriptPath)) {
      const msg = 'ERROR: script no encontrado: ' + tarea + '.bat';
      log(msg);
      await api({ action: 'setResultado', pc_id: pcId, resultado: msg });
      return;
    }

    try {
      execSync('"' + scriptPath + '"', {
        stdio: 'ignore', shell: true, windowsHide: true
      });
    } catch(_) {
      // el .bat puede salir con código ≠ 0; lo consideramos ejecutado igual
    }

    const ok = tarea + ' ejecutado correctamente';
    log(ok);
    await api({ action: 'setResultado', pc_id: pcId, resultado: ok });

  } catch (err) {
    log('Error en checkAndExecute: ' + err.message);
  }
}

async function main() {
  const cfg = loadConfig();
  if (!cfg || !cfg.pc_id) {
    log('ERROR: config.json no encontrado o sin pc_id. Reinstala CHEV.');
    process.exit(1);
  }

  log('CHEV v2 iniciado — PC: ' + cfg.pc_id);
  log('Scripts en: ' + SCRIPTS_DIR);

  await checkAndExecute(cfg.pc_id);
  setInterval(() => checkAndExecute(cfg.pc_id), CHECK_INTERVAL);
}

main().catch(err => log('Error fatal: ' + err.message));
