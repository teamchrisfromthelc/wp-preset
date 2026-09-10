---
name: figma-to-wordpress
description: Use when implementing a Figma design on an existing WordPress site (full or partial redesign). Triggers on "Figma to WordPress", "implement Figma design", "WordPress redesign", "rebuild WP site from Figma", "build WordPress page from Figma", "convert Figma to Divi/Elementor/Gutenberg". CORE RULE - never guess an element's CSS values (font-size, radius, padding, color); always read them from the specific Figma node first, then verify the built page by MEASURING the rendered DOM against the Figma geometry. Works with any page builder (Elementor, Gutenberg/blocks, Divi). Ships verification scripts + per-builder notes.
---

# Figma → WordPress

Take a finished Figma design and implement it faithfully on an existing WordPress site. The whole skill rests on two disciplines that most "Figma to code" flows skip:

1. **Never guess a value - read it from the node.** Screenshots make you hallucinate "close enough but exactly wrong" values.
2. **Don't trust your eyes - measure.** Converge by comparing the rendered DOM's real geometry to Figma's, not by eyeballing two screenshots.

Two ways to build:

- **Manual builder** - click through Elementor/Divi/Gutenberg module-by-module. Slow, no setup, good when you lack DB access or are watched while building.
- **Code-gen + DB injection + measure loop** - generate builder markup, inject via SQL, render headless, *measure* against Figma, iterate. Much faster once set up. This skill biases toward it but the two disciplines apply to both.

## When it applies
An existing WordPress site needs a visual redesign from a Figma file; the design is (mostly) finalized upstream; the goal is to get it live on the real domain. **Not** for greenfield-from-prompt, headless WP, or WP→other-platform migrations.

---

## ⭐ Core rule: never guess element specs - read them from the node

**Before you state ANY specific CSS value (font-size, border-radius, padding, line-height, gap, exact hex, exact px) for a specific element, fetch that element's spec from Figma first** - `mcp__figma__get_design_context` on that exact node (or the Dev Mode CSS panel). No exceptions when the data is available.

### The failure mode this prevents
It's tempting to infer a specific element's values from a low-res screenshot, or to default to "common patterns" ("most CTAs are 14px Bold pill"). This produces values that are *approximately* right and *exactly* wrong - and each one is "close enough to look reasonable," so nothing trips an alarm.

**Real example:** a session told the user a header CTA button was "border-radius 44px (pill), 14px, Bold" because the screenshot *looked* like a pill and those are common defaults. The actual Figma spec was `border-radius: 8px`, `font-size: 13px`, `font-weight: 500 (Medium)`. Every value wrong by a small amount. Caught only because the user had Dev Mode open - otherwise the whole site ships with subtly wrong typography and corner radii, and the designer notices in review.

### The correct workflow per element
1. **Identify the node** - from `get_metadata` on the parent frame, or a Figma URL `?node-id=X-Y`.
2. **Call `mcp__figma__get_design_context`** on that exact `nodeId` (`excludeScreenshot: true` to save tokens).
3. **Read the returned code** - it carries the same exact values Figma's Dev Mode shows: `text-[Npx]`, `font-['Family:Weight']`, `leading-[Npx]`, `rounded-[Npx]`, `bg-[#hex]`, `p-[N]`.
4. **Translate verbatim** into the target builder's settings. If the builder wants integers and Figma gives 8.75px, round - but only after seeing the source.
5. **Say the values came from the spec**, so the user can sanity-check the same node in Dev Mode.

✅ "Border-radius 8px, padding 9/25/9/23, Plus Jakarta Sans Medium 13px, line-height 22px - sourced from the button's Figma node; verify in Dev Mode."
❌ "Looks pill-shaped, probably 14px Bold like a normal CTA - radius 44px, 14px, Bold." *(then the user corrects you and you redo it)*

### When whole-frame grepping IS fine
Only for *discovery of the set*, never for one element's value:
- Palette - grep `#[0-9a-fA-F]{6}` across the whole-frame context.
- Type ramp - grep `text-\[Npx\]` / `font-\[` patterns.
- Which icons need extraction - scan small (≤48px) frames.

The moment you go from "what tokens does this file use" to "what should THIS element's settings be" → switch to per-node `get_design_context`. Per-node calls are ~1-15K chars; trivial next to the cost of wrong values.

### When the MCP can't answer (rare)
Code Connect component without resolved props, an old file format, or a rate-limited server. Then: try `get_screenshot` at high resolution and read values from it; or ask the user to paste the Dev Mode CSS. **Never silently fall back to guessing** - always say "couldn't resolve via MCP, here's how I'm deriving this" so the user can verify.

---

## Step 0: recon the WordPress site (5 min)
Before choosing a path, know what you're on. Have the user (in wp-admin) check:
1. **Active theme** + child theme. Block theme (has Appearance → Editor) or classic?
2. **Page editor** - open a page → edit: Gutenberg blocks? Elementor? Divi? Classic?
3. **Plugins** - builder, migration tool (All-in-One WP Migration is friendliest), caching, forms. **If SVG upload isn't enabled, install Safe SVG now** so you don't hit the wall mid-build.
4. **Role** = Administrator. **Hosting access** - wp-admin only? Local dev environment?

## Decision tree → builder notes
| Builder found | Path | Per-builder note |
|---|---|---|
| **Elementor** (classic widgets) | widgets → polish | [`references/builders/elementor.md`](references/builders/elementor.md) |
| **Gutenberg / FSE** | native blocks + `theme.json` | [`references/builders/gutenberg.md`](references/builders/gutenberg.md) |
| **Divi 4** | shortcodes (manual or SQL-injected) | [`references/builders/divi.md`](references/builders/divi.md) |
| **Bricks / Oxygen** | builder elements → polish | method still applies; no dedicated note yet |
| **Classic theme, custom HTML** | child theme + custom templates | go file-based (see "when to skip the builder") |

The two disciplines (never-guess + measure) are builder-agnostic. The builder note only tells you *where content is stored* and *how to inject*.

---

## Asset extraction: SVG over PNG → [`references/figma-rest.md`](references/figma-rest.md)
For any icon, logo, or illustration, export **SVG via the Figma REST API** (`/v1/images?ids=...&format=svg`) - not `get_screenshot` (PNG-by-default). Use PNG only when the API returns `null` (flattened bitmap) or for genuine raster photos. Set a read-only token as `$FIGMA_PAT`. `scripts/figma-geom.py` pulls frame-relative geometry for the measure loop. Full setup + batch commands in the reference.

## Static vs dynamic: build editable content the WordPress way (decide at recon)
Code-gen produces **static** layouts - every card hard-coded. Correct for fixed marketing copy (hero, about, CTA); **wrong** for anything the client updates over time (news, products, events, team, testimonials, directories). Hard-coding editable content means the client can't change it without a developer.

**At recon, classify every section static vs dynamic, and ask the client: "which of these will you edit yourself after launch?"** For the dynamic ones, build the WordPress way: native **Posts** for news/blog; a **Custom Post Type + fields** for products/events/team. Render via the builder's loop widget (or a small `WP_Query` shortcode if the builder's free tier has no loop), then style the loop output to match Figma per-node, same as static - only the *content* comes from the query. Rule of thumb: if someone would otherwise get a "can you add this month's news?" email forever, it must be dynamic. Retrofitting a hard-coded section into a loop after launch costs far more than building it dynamic once.

---

## The build loop - MEASURE-first (the fast, accurate path)
Converge on the **spec**, not on a screenshot diff. Eyeballing two screenshots is the slow, low-accuracy path (5-8 cycles); measuring the rendered DOM against Figma's exact values converges in 1-2.

1. **Spec** - `get_design_context` on the node (exact px/hex/weight; never-guess).
2. **Generate** the builder markup for the section.
3. **Inject** into the WP DB (or build it in the editor).
4. **Regenerate caches** - *skip this and a correct fix is invisible, so you'll falsely call it done.*
   - Elementor: delete the page's `_elementor_css` postmeta + `uploads/elementor/css/post-<ID>.css` + the `_elementor_global_css` option, or **Elementor → Tools → Clear Files & Data**.
   - Divi: `rm -rf wp-content/et-cache/` + delete `_transient_%et%` options.
5. **Measure, don't look:**
   ```bash
   node scripts/dom-measure.js  http://localhost:PORT/your-page/ 1440 ".target" "h1" "p"
   node scripts/overflow-sweep.js http://localhost:PORT/your-page/ 390,430,768,1440,1920
   ```
   `dom-measure.js` prints each selector's computed box + styles → **diff against the Figma values; that diff IS your fix list.** `overflow-sweep.js` is a hard gate (exit 1 on any horizontal overflow).
6. **Fix the measured deltas → re-measure** until within tolerance.
7. **Then screenshot once**, multi-viewport - a *gross-structure* sanity check (section order, empty voids, things numbers can't see). NOT the convergence tool.

Measured DOM comparison is the only thing that reliably surfaces the fine bugs (an off-centre element, a wrong size, a missing 1px hairline). Screenshots are for gross structure only.

The JS tools share `scripts/lib-playwright.js`, which auto-resolves chrome-headless-shell and auto-installs `playwright-core` on first run - no manual path-wrangling. Run `scripts/env-detect.sh --url localhost:PORT` once at session start to discover php/mysql/chromium/node + your socket (the `--url` picks the RIGHT LocalWP socket when several sites run - avoids the wrong-DB trap).

## Verify before declaring "done" (every page - don't wait to be asked)
Three gates, in order of how much truth they produce:
1. **Multi-viewport overflow sweep + band-read.** Run `overflow-sweep.js` across **360, 390, 768, 991, 1024, 1280, 1440, 1680, 1920**. Fix every offender to zero horizontal scroll. **Do NOT stop at 1440** - wide screens (1680/1920) are where fixed-px content stops filling and leaves big right-side gaps; content that won't fill wide must be proportional (%/flex), not fixed px. **Primary mobile viewport = 390×844 (iPhone-class), DPR 3** - a desktop-DPR-1 390 screenshot can look fine while a real phone is broken. Then read a real **full-page** screenshot in vertical bands (use Playwright `fullPage:true`; a tall `--window-size` fakes the height and invents empty gaps).
2. **Measured DOM comparison (the real fine gate)** - for each section that must match Figma, read the rendered element's exact `getBoundingClientRect()` / `getComputedStyle()` (px + hex) and diff against the Figma node. Trust numbers over any model's visual claim for anything sub-perceptual.
3. **Structural subagent verifier (optional, gross-shape only)** - a fresh, no-build-context agent given a CLOSED checklist (sections present + in order? missing/duplicated/overlapping? big empty void?), layout-only, no text transcription. **Do NOT use it for fine spacing/size/colour - it confabulates** (it will invent "rounded corners / tighter spacing / wrong weight" that are all false on inspection, and miss the real bugs). Verify the Figma reference is the correct/current frame first.

Match the tier to the change: text/color tweak → `curl | grep` the HTML; possible layout change → one 390 screenshot; structural/responsive change → the full sweep. When in doubt, screenshot.

## After ANY fix: prove it RENDERED before saying "done" (anti-fake-fix rule)
The most infuriating failure mode: the user asks for a small fix, the session edits CSS and reports "fixed" - but the live page is unchanged, so it bounces back 3-4 times. Root cause: **the session confirmed it WROTE the change, not that the change RENDERED. Reading your own diff is not verification.**

A fix is not done until you've re-rendered and **measured the specific thing you changed**:
1. Apply the edit. 2. **Regenerate caches** (the #1 reason an edit shows no change). 3. Assert the changed property on the rendered page, targeted - and **measure the innermost VISIBLE element, not a wrapper** (a wrapper can fill its slot while the visible field inside doesn't - the number is true and misleading). **Verify at multiple widths** - "passes at 1440" is not done. 4. Only say "done" if the measured value is the new one, on the right element, at every width.

If it still reads the old value, check in order: cache not regenerated → wrong selector/node → specificity/`!important` lost (a page-scoped `body.page-id-N` rule out-specifies a global one; or `background:` shorthand nuked your longhand) → the builder silently dropped the prop.

---

## Multi-page efficiency: reuse the debugged generator, copy signed-off sections
Page 2+ is fast because you inherit a **working generator**, not because you skip reading Figma (never-guess still applies every page).
- **Clone the debugged per-page builder script**, helpers verbatim - you inherit a correct schema + working helpers instead of fighting the markup format from zero.
- **Copy a signed-off section verbatim and adapt content** - heroes, CTAs, maps are copy-paste-adapt jobs; never re-derive their geometry, and **never rebuild a correct section just to make a tool's report go green** (a metric is not a target - an agent will bulldoze 3 good sections to silence 1 finding). But "copied" isn't self-verifying: after a copy, assert a checkable outcome ("hero image covers the card, no background-fill visible"), and for alignment use an **anchor** ("field A's top aligns to field B's top"), not "make them equal height."
- **Gutters are per-section - read each section's inset from Figma.** There is NO single global gutter; bands in the same design often sit at different insets. Full-bleed coloured bands = full-width section + per-section inner padding read from Figma.

Each page is its own builder script + its own data row → safe to build concurrently; the only shared resources are site-wide (global kit / theme options) - set those once, never let two sessions write them at once. You're the screenshot-review bottleneck, so ~2-3 parallel sessions, not 5.

Honest about what this does NOT remove: net-new sections still need full per-node spec work, desktop still takes a polish loop, and mobile needs explicit responsive variants - budget for it.

---

## The honest counter-case: when to skip the page builder
This skill generates page-builder output because that's usually the constraint - client sites already run Elementor/Divi/Astra. **On most tasks you don't get to choose.** But be honest: the recurring consensus among working WP devs is that **AI is weakest at page-builder internals and strongest at file-based work** (classic/block themes, hooks, CPTs, REST endpoints, small custom blocks). The size of the gotchas catalog is itself evidence.

**When you actually have latitude** - a greenfield page, a client who won't self-edit, a site not yet committed to a builder - a **file-based block or classic theme + custom CSS** is genuinely less fighting. The canonical resource is the official **`WordPress/agent-skills`** repo (github.com/WordPress/agent-skills) - file-based block/theme/plugin skills, `theme.json`, patterns. Pair it with this skill's Figma discipline: the never-guess rule + REST asset pipeline transfer cleanly; only the *output target* changes to block markup / `theme.json`.

For block themes there's a mature token pipeline: build the Figma style guide on **Figma variables**, then export them to `theme.json` with a plugin (`10up/figma-to-wordpress-theme-json-exporter`, or the actively-evolving bidirectional fork `linchpin/figma-wordpress-theme-json-sync`) instead of hand-transcribing - tokens cross the boundary as structured data, sidestepping the never-guess problem for tokens entirely. Then generate each page as a reviewable `.php`/block template. Block markup is also easier for an LLM to emit than builder shortcodes.

---

## Reference index
- [`references/figma-rest.md`](references/figma-rest.md) - Figma REST API: token setup, batch SVG export, image-fill download.
- [`references/environment.md`](references/environment.md) - discover LocalWP socket, bundled mysql/php, Chromium, site URL.
- [`references/gotchas-general.md`](references/gotchas-general.md) - builder-agnostic traps (LocalWP, CSS specificity, image MIME, migration, fonts).
- [`references/tool-reference.md`](references/tool-reference.md) - LocalWP, AIOWPM, Figma MCP+REST, Playwright, Safe SVG, LiteSpeed.
- [`references/going-live.md`](references/going-live.md) - deploy a LocalWP build to a live host (DirectAdmin), end to end.
- [`references/builders/`](references/builders/) - per-builder notes: Elementor, Gutenberg, Divi.

**Scripts** (`scripts/`): `env-detect.sh` (toolchain + socket), `figma-geom.py` (Figma geometry), `dom-measure.js` (measure rendered element vs spec), `overflow-sweep.js` (overflow gate), `figma-build-diff.py` (Figma-anchored layout diff - diagnostic only, never an auto-fix gate), `lib-playwright.js` (shared headless helper).
