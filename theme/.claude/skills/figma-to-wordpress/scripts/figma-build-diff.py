#!/usr/bin/env python3
"""
figma-build-diff.py - compare a built WP page to its Figma design, in NUMBERS.

Outputs px deltas per text-matched element (NOT verdicts): "build left X / Figma Y
/ Δ". At the Figma frame width it's a direct match; at wider widths it reports
content symmetry (left vs right gutter) since Figma has no wide reference. This is
the Figma-anchored layout diff - ground truth is Figma, so no false positives on
intentional insets.

Requires: FIGMA_PAT in env; CHS = chrome-headless-shell path; playwright-core
installed (cd /tmp && npm i playwright-core). Reads figma-geom.py + dom-geom.js
from the same dir.

Usage:
  FIGMA_PAT=... CHS=... python3 figma-build-diff.py <url> <fileKey> <pageId> <frameId> [widths]
  e.g. ... http://localhost:PORT/your-page/ <FILE_KEY> <pageNodeId> <frameNodeId> 1440,1920
"""
import os, sys, json, subprocess, re

HERE = os.path.dirname(os.path.abspath(__file__))
URL, KEY, PAGE, FRAME = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
WIDTHS = [int(w) for w in (sys.argv[5] if len(sys.argv) > 5 else "1440,1920").split(",")]

def norm(t):
    t = (t or "").lower().strip().rstrip("*").strip()
    t = re.sub(r"\s+", " ", t)
    return t[:40]

# --- Figma elements (at frame width) ---
fg = json.loads(subprocess.check_output(["python3", os.path.join(HERE, "figma-geom.py"), KEY, PAGE, FRAME], env={**os.environ}))
FW = fg["frame"]["w"]
# group ALL figma instances by text (keep duplicates - resolve by nearest position)
from collections import defaultdict
fgroups = defaultdict(list)
for e in fg["elements"]:
    k = norm(e["text"])
    if k:
        fgroups[k].append(e)
fmap = {k: max(v, key=lambda e: e["w"] * e["h"]) for k, v in fgroups.items()}  # for membership tests

def dom_at(width):
    out = subprocess.check_output(["node", os.path.join(HERE, "dom-geom.js"), URL, str(width)], env={**os.environ})
    return json.loads(out)

print(f"# Figma-anchored layout diff - {URL}")
print(f"# Figma frame width = {FW}px; matched by text. Δ = build − Figma (px). NUMBERS, not verdicts - confirm against Figma.\n")

for width in WIDTHS:
    dom = dom_at(width)
    dmap = {}
    for e in dom["els"]:
        k = norm(e["text"])
        if not k: continue
        if k not in dmap or e["w"] * e["h"] > dmap[k]["w"] * dmap[k]["h"]:
            dmap[k] = e
    print(f"===== width {width}px (scrollW {dom['scrollW']}) =====")
    if dom["scrollW"] > width + 1:
        print(f"  ⚠ HORIZONTAL OVERFLOW: scrollW {dom['scrollW']} > {width}")

    if width == FW:
        # direct Figma match - for each build element, the NEAREST same-text Figma node
        rows = []
        for k, d in dmap.items():
            cands = fgroups.get(k)
            if not cands: continue
            f = min(cands, key=lambda c: abs(c["x"] - d["left"]) + abs(c["y"] - d["top"]))
            dl, dw, dh = d["left"] - f["x"], d["w"] - f["w"], d["h"] - f["h"]
            icon = "  ⚠NO-ICON(Figma has one)" if f["icon"] and not d["svg"] else ""
            # left & icon are reliable; width is noisy (text matched to a container) → only note if both look like the same kind of node
            wnote = f"(Δ{dw:+})" if abs(f["w"] - d["w"]) < max(f["w"], d["w"]) * 0.6 else "(n/a)"
            rows.append((abs(dl) + (1000 if icon else 0), f, d, dl, dw, dh, icon, wnote))
        rows.sort(key=lambda r: r[0], reverse=True)
        print(f"  matched {len(rows)} elements (worst first; LEFT + ICON are the reliable signals, width n/a = node-granularity mismatch):")
        for _, f, d, dl, dw, dh, icon, wnote in rows[:20]:
            flag = "  <<<" if abs(dl) > 12 or icon else ""
            print(f"    {f['text'][:30]!r:32} left {d['left']:>4}/{f['x']:<4}(Δ{dl:+}) w {wnote} h(Δ{dh:+}){icon}{flag}")
    else:
        # wide screen: no Figma ref → report content symmetry of matched elements
        ls = [d["left"] for k, d in dmap.items() if k in fmap]
        rs = [width - (d["left"] + d["w"]) for k, d in dmap.items() if k in fmap]
        if ls:
            lg, rg = min(ls), min(rs)
            print(f"  content left gutter {lg}px vs right gutter {rg}px  →  {'ASYMMETRIC Δ'+str(abs(lg-rg)) if abs(lg-rg) > 16 else 'symmetric'}")
            print(f"  (Figma has no {width} frame - this is an internal symmetry/fill check, not a Figma match)")
    print()
