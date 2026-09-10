// dom-measure.js - measure rendered elements on a live page (the "numbers > screenshots"
// truth-teller). For each CSS selector, prints the bounding box + key computed styles at a
// given viewport width. Use to diff a build against Figma specs, or to debug layout.
//
// Usage:  node dom-measure.js <url> <width> "<sel1>" "<sel2>" ...
//   e.g.  node dom-measure.js http://localhost:PORT/your-page/ 1440 ".page-content" "h1"
// Needs node + the chromium-headless-shell (auto-resolved by lib-playwright.js; it
// auto-installs playwright-core to ~/.cache/fig2wp on first run). Run from this scripts/ dir,
// or from anywhere - it require()s lib-playwright by absolute path.
const { launch } = require(require('path').join(__dirname, 'lib-playwright.js'));

(async () => {
  const url = process.argv[2];
  const width = parseInt(process.argv[3], 10) || 1440;
  const selectors = process.argv.slice(4);
  if (!url || !selectors.length) {
    console.error('Usage: node dom-measure.js <url> <width> "<selector>" ["<selector>" ...]');
    process.exit(2);
  }
  const b = await launch();
  const p = await b.newPage();
  await p.setViewportSize({ width, height: 1000 });
  await p.goto(url, { waitUntil: 'load', timeout: 30000 });
  await p.waitForTimeout(1200);
  const out = await p.evaluate(({ vw, sels }) => {
    const res = { vw };
    for (const sel of sels) {
      const el = document.querySelector(sel);
      if (!el) { res[sel] = '(not found)'; continue; }
      const c = getComputedStyle(el), r = el.getBoundingClientRect();
      res[sel] = {
        left: Math.round(r.left), right: Math.round(vw - r.right), top: Math.round(r.top),
        width: Math.round(r.width), height: Math.round(r.height),
        maxWidth: c.maxWidth, marginL: c.marginLeft, marginR: c.marginRight,
        padL: c.paddingLeft, padR: c.paddingRight,
        font: `${c.fontSize}/${c.lineHeight} ${c.fontWeight}`, color: c.color,
        bg: c.backgroundColor, radius: c.borderRadius, textAlign: c.textAlign, display: c.display,
      };
    }
    return res;
  }, { vw: width, sels: selectors });
  console.log(JSON.stringify(out, null, 1));
  await b.close();
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
