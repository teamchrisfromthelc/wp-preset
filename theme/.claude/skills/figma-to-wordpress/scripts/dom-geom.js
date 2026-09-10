#!/usr/bin/env node
/**
 * dom-geom.js - dump frame-relative geometry of every meaningful rendered node.
 * Contract expected by figma-build-diff.py:
 *   { scrollW: <int>, els: [ {text, left, top, w, h, svg} ] }
 * Coordinates are document-relative (page top-left), matching Figma frame coords.
 */
const path = require('path');
const URL_ = process.argv[2];
const WIDTH = parseInt(process.argv[3] || '1440', 10);

function resolvePlaywright() {
  const cands = [
    path.join(process.env.HOME, '.cache/fig2wp/node_modules/playwright-core'),
    'playwright-core',
  ];
  for (const c of cands) { try { return require(c); } catch (e) {} }
  throw new Error('playwright-core not found');
}

(async () => {
  const { chromium } = resolvePlaywright();
  const exe = process.env.CHS || process.env.CHS_PATH || undefined;
  const browser = await chromium.launch(exe ? { executablePath: exe } : {});
  const page = await browser.newPage({ viewport: { width: WIDTH, height: 1000 } });
  await page.goto(URL_, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);

  const data = await page.evaluate(() => {
    const out = [];
    const sx = window.scrollX, sy = window.scrollY;
    const seen = new Set();
    document.querySelectorAll('body *').forEach((el) => {
      const cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden') return;
      const r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2) return;
      // own text = direct text children only, so a wrapper doesn't steal its child's label
      let own = '';
      for (const n of el.childNodes) {
        if (n.nodeType === 3) own += n.nodeValue;
      }
      own = own.replace(/\s+/g, ' ').trim();
      // fall back to full text for leaf-ish nodes (links, headings with inline spans)
      if (!own && el.children.length <= 2) {
        own = (el.textContent || '').replace(/\s+/g, ' ').trim();
      }
      if (!own) return;
      if (own.length > 200) return;
      const key = own.slice(0, 40) + '|' + Math.round(r.left) + '|' + Math.round(r.top);
      if (seen.has(key)) return;
      seen.add(key);
      out.push({
        text: own,
        left: Math.round(r.left + sx),
        top: Math.round(r.top + sy),
        w: Math.round(r.width),
        h: Math.round(r.height),
        svg: !!el.querySelector('svg, img[src$=".svg"]'),
      });
    });
    return { scrollW: document.documentElement.scrollWidth, els: out };
  });

  console.log(JSON.stringify(data));
  await browser.close();
})().catch((e) => { console.error(e.message); process.exit(1); });
