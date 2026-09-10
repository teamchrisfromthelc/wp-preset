#!/usr/bin/env python3
"""
figma-geom.py - extract frame-relative geometry of a Figma page region via REST.

Outputs clean JSON [{text, name, x, y, w, h, icon}] for every meaningful node whose
absoluteBoundingBox falls inside a target frame's box - handles designs that are
NOT cleanly nested (loose siblings on the canvas), which `get_metadata`'s frame-
children call misses. Uses REST `absoluteBoundingBox` (already absolute) so there's
NO parent-offset tree-walking. `text` = the node's own characters or its first text
child (for matching to the DOM). `icon` = has a small vector/icon child.

Usage: FIGMA_PAT=... python3 figma-geom.py <fileKey> <pageNodeId> <frameNodeId>
  e.g. python3 figma-geom.py <FILE_KEY> <pageNodeId> <frameNodeId>
"""
import os, sys, json, urllib.request

KEY, PAGE, FRAME = sys.argv[1], sys.argv[2], sys.argv[3]
PAT = os.environ.get("FIGMA_PAT", "")
if not PAT:
    sys.exit("FIGMA_PAT not set")

def fetch(ids):
    url = f"https://api.figma.com/v1/files/{KEY}/nodes?ids={ids}"
    req = urllib.request.Request(url, headers={"X-Figma-Token": PAT})
    return json.load(urllib.request.urlopen(req, timeout=60))

# 1. frame box (the spatial region we care about)
fr = fetch(FRAME)["nodes"][FRAME.replace("-", ":")]["document"]
FB = fr["absoluteBoundingBox"]
fx, fy, fw, fh = FB["x"], FB["y"], FB["width"], FB["height"]

# 2. full page, then spatial-filter to the frame box
page = fetch(PAGE)["nodes"][PAGE.replace("-", ":")]["document"]

TEXT_TYPES = {"TEXT"}
def own_text(n):
    if n.get("type") in TEXT_TYPES:
        return (n.get("characters") or n.get("name") or "").strip()
    # first text descendant
    for c in n.get("children", []):
        t = own_text(c)
        if t:
            return t
    return ""
def has_icon(n):
    for c in n.get("children", []):
        bb = c.get("absoluteBoundingBox") or {}
        nm = (c.get("name") or "").lower()
        if c.get("type") in ("VECTOR", "BOOLEAN_OPERATION") or (bb.get("width", 99) <= 40 and bb.get("height", 99) <= 40 and any(k in nm for k in ("icon", "send", "mail", "arrow", "chevron", "pin", "phone", "clock"))):
            return True
    return False

out = []
def walk(n):
    bb = n.get("absoluteBoundingBox")
    if bb and bb["width"] > 0 and bb["height"] > 0:
        cx, cy = bb["x"] + bb["width"] / 2, bb["y"] + bb["height"] / 2
        inside = fx - 5 <= cx <= fx + fw + 5 and fy - 5 <= cy <= fy + fh + 5
        if inside and n.get("id") != fr.get("id") and bb["width"] < fw * 0.99:
            out.append({
                "id": n.get("id"), "name": (n.get("name") or "")[:30],
                "text": own_text(n)[:40], "type": n.get("type"),
                "x": round(bb["x"] - fx), "y": round(bb["y"] - fy),
                "w": round(bb["width"]), "h": round(bb["height"]),
                "right": round(fw - (bb["x"] - fx + bb["width"])),  # right gutter
                "icon": has_icon(n),
            })
    for c in n.get("children", []):
        walk(c)
walk(page)

# keep text-bearing or sizable nodes; drop tiny noise
out = [e for e in out if (e["text"] or (e["w"] >= 40 and e["h"] >= 24))]
print(json.dumps({"frame": {"x": fx, "y": fy, "w": fw, "h": fh}, "count": len(out), "elements": out}, ensure_ascii=False))
