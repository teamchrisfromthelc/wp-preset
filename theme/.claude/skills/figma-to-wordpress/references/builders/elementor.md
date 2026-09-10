<!-- Part of the figma-to-wordpress skill. Applies the never-guess method to Elementor. -->

# Builder note: Elementor

How the method maps to Elementor: read exact values per Figma node (font size, weight, line-height, radius, padding, color), then build them as **Elementor widgets** with those literal values - never eyeball. Verify by measuring the rendered DOM against Figma geometry (see "Verification" below). This note covers Elementor **classic widgets** (the common case); the bleeding-edge V4 "atomic" engine is out of scope here.

## Where Elementor stores page content
- A page's layout lives in **post meta** `_elementor_data` (a big JSON blob), not in `post_content`. The `_elementor_css` meta + files under `wp-content/uploads/elementor/css/` are generated caches.
- **Prefer building in the editor** (or via the editor's copy/paste) over hand-authoring `_elementor_data` JSON. Hand-written JSON that doesn't match Elementor's exact schema can make a page **uneditable** in the editor ("invalid" widget) - a painful retrofit. If you must script DB changes, keep widgets to shapes the editor itself produces.
- After ANY direct DB edit to `_elementor_data`, regenerate caches: **Elementor → Tools → Regenerate CSS & Data** (older builds) / **Clear Files & Data** (Elementor 7+). Otherwise your change is invisible.

## Field notes
- **http CSS on an https page after migration.** Post-migration, Elementor CSS files can be referenced over `http` → browsers block them on an https page → page content renders unstyled while the theme header/footer look fine. Fix at runtime with Really Simple SSL, then bake it in via Clear Files & Data. (Symptom: "header+footer styled, everything between is huge unstyled icons + text.")
- **Map Figma tokens to Elementor Global styles** (Site Settings → Global Colors / Global Fonts) once, then reference them - so a palette change is one edit, not fifty.
- **SVG icons need an enabler.** WordPress blocks SVG upload by default; install Safe SVG (or enable Elementor's Unfiltered File Uploads on local-only dev) before you start placing icons.
- **Don't trust the editor canvas for final pixels** - it renders inside an iframe with editor chrome. Measure on the real front-end URL.
- **Containers vs. sections:** new Elementor defaults to flexbox **Containers**. They map cleanly to Figma auto-layout frames (direction, gap, padding, align/justify) - prefer them over legacy Section/Column for new builds.

## Verification (always)
From the repo's `scripts/`:
```bash
# horizontal-overflow sweep across breakpoints
node scripts/overflow-sweep.js http://localhost:PORT/your-page/ 390,430,768,1440,1920
# measure a specific element vs its Figma spec values
node scripts/dom-measure.js http://localhost:PORT/your-page/ 1440 ".your-widget" "h1"
```
Compare measured box + computed styles against the Figma node values you pulled. Differences are the bug list - don't declare "done" off a thumbnail.
