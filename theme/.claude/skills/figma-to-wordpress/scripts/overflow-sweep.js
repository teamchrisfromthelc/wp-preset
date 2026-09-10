// overflow-sweep.js - the one INTENT-INDEPENDENT hard gate. Loads a URL at several
// viewport widths and reports horizontal overflow (scrollWidth > clientWidth) plus the
// widest offending elements. Unlike layout/visual deltas (design-intent-dependent, human-
// judged), overflow is always a bug - safe to auto-fail a build on.
//
// Usage:  node overflow-sweep.js <url> [widths]
//   e.g.  node overflow-sweep.js http://localhost:PORT/ 390,430,768,1440,1920
// Exit 0 = clean at every width, 1 = overflow at some width (so it can gate).
const { launch } = require(require('path').join(__dirname, 'lib-playwright.js'));

(async () => {
  const url = process.argv[2];
  const widths = (process.argv[3] || '390,430,768,1440,1920').split(',').map((w) => parseInt(w, 10));
  if (!url) { console.error('Usage: node overflow-sweep.js <url> [w1,w2,...]'); process.exit(2); }
  const b = await launch();
  const p = await b.newPage();
  await p.goto(url, { waitUntil: 'load', timeout: 30000 });
  let bad = false;
  for (const w of widths) {
    await p.setViewportSize({ width: w, height: 1000 });
    await p.waitForTimeout(400);
    const r = await p.evaluate((vw) => {
      const de = document.documentElement;
      const sw = de.scrollWidth, cw = de.clientWidth;
      if (sw <= cw + 1) return { overflow: false, sw, cw };
      const offenders = [];
      for (const el of document.querySelectorAll('*')) {
        const b = el.getBoundingClientRect();
        if (Math.round(b.right) > cw + 1) {
          offenders.push({ tag: el.tagName.toLowerCase(), cls: (el.className || '').toString().split(' ').slice(0, 2).join('.'), right: Math.round(b.right), w: Math.round(b.width) });
        }
      }
      offenders.sort((a, b) => b.right - a.right);
      return { overflow: true, sw, cw, offenders: offenders.slice(0, 6) };
    }, w);
    if (r.overflow) {
      bad = true;
      console.log(`⚠ ${w}px OVERFLOW: scrollWidth ${r.sw} > clientWidth ${r.cw}`);
      for (const o of r.offenders) console.log(`    ${o.tag}.${o.cls}  right=${o.right} w=${o.w}`);
    } else {
      console.log(`✓ ${w}px clean (scrollWidth ${r.sw})`);
    }
  }
  await b.close();
  console.log(bad ? '\nFAIL: horizontal overflow found.' : '\nPASS: no overflow at any width.');
  process.exit(bad ? 1 : 0);
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
