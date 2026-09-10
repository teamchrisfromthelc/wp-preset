// lib-playwright.js - shared, self-healing Playwright loader for the skill's JS tools.
// Centralizes the two things that broke repeatedly in real builds:
//   1. finding the chromium-headless-shell binary (no Chrome.app / no sudo needed)
//   2. resolving playwright-core (auto-installs to a stable cache dir on first use,
//      instead of a throwaway /tmp install that vanishes between sessions)
// Used by dom-measure.js and overflow-sweep.js. require('./lib-playwright.js').launch().
const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

function newestGlob(dir, re) {
  let best = null;
  try {
    for (const name of fs.readdirSync(dir)) {
      if (re.test(name)) { const full = path.join(dir, name); if (!best || full > best) best = full; }
    }
  } catch {}
  return best;
}

function findChromium() {
  if (process.env.CHS && fs.existsSync(process.env.CHS)) return process.env.CHS;
  const base = path.join(os.homedir(), 'Library/Caches/ms-playwright');
  const shellDir = newestGlob(base, /^chromium_headless_shell-/);
  if (shellDir) {
    const inner = newestGlob(shellDir, /^chrome-headless-shell-mac/);
    if (inner) { const bin = path.join(inner, 'chrome-headless-shell'); if (fs.existsSync(bin)) return bin; }
  }
  // fall back to a full chromium build if that's what's installed
  const chromeDir = newestGlob(base, /^chromium-/);
  if (chromeDir) {
    for (const p of ['chrome-mac/Chromium.app/Contents/MacOS/Chromium', 'chrome-mac-arm64/Chromium.app/Contents/MacOS/Chromium']) {
      const bin = path.join(chromeDir, p); if (fs.existsSync(bin)) return bin;
    }
  }
  throw new Error('chromium-headless-shell not found. Install once: npx playwright install chromium  (or set $CHS to the binary).');
}

function requirePlaywrightCore() {
  const cacheDir = path.join(os.homedir(), '.cache', 'fig2wp');
  const candidates = [
    path.join(__dirname, 'node_modules', 'playwright-core'),
    path.join(cacheDir, 'node_modules', 'playwright-core'),
  ];
  for (const c of candidates) { try { return require(c); } catch {} }
  try { return require('playwright-core'); } catch {}
  // self-heal: install once into the stable cache dir
  fs.mkdirSync(cacheDir, { recursive: true });
  process.stderr.write('playwright-core not found - installing once into ~/.cache/fig2wp …\n');
  execSync('npm i playwright-core --no-save --no-audit --no-fund --silent', { cwd: cacheDir, stdio: 'inherit' });
  return require(path.join(cacheDir, 'node_modules', 'playwright-core'));
}

async function launch() {
  const { chromium } = requirePlaywrightCore();
  return chromium.launch({ executablePath: findChromium(), args: ['--no-sandbox', '--hide-scrollbars', '--disable-gpu'] });
}

module.exports = { launch, findChromium };
