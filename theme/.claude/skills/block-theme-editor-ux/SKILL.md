---
name: block-theme-editor-ux
description: Audit and fix the editor side of a finished WordPress block theme so the Site Editor and post editor match the front end, every section is labelled in List View, structure is locked to content-only editing, new pages start from the right template and the inserter is curated. Use this whenever the front end is done and must not change but the client-facing editing experience needs work. Trigger on phrases like "the editor doesn't match the front end," "List View is all Groups," "the client can't edit this," "lock the layout," "clean up the inserter," "editor UX," "curate the editor," or any request to make the back end of a block theme usable for non-technical users. Runs as audit → stop for approval → apply → verify by measurement.
---

# Block theme editor UX

Front-end output is frozen. Every change here is editor-only. If a fix would
alter front-end markup or CSS, stop and flag it before applying.

Tested against: WordPress 7.1. If the site runs a different major version,
re-measure anything in `references/editor-dom-differences.md` before trusting
it; those entries are Gutenberg internals and drift between releases.

## Files in this skill

- `references/editor-dom-differences.md`: known editor-vs-front-end DOM and
  CSS differences and the editor-only fix for each. Read it during the audit
  (item 3) and whenever a measurement in verify comes back off.
- `references/verify-scripts.md`: spec for the Playwright scripts in
  `scripts/`. If `scripts/` is empty, write the scripts from that spec once,
  test them and commit them. Never re-derive them inline during a run.
- `scripts/`: `mint-cookies.sh`, `measure.mjs`, `dump-listview.mjs`,
  `check-locks.mjs`, `dump-inserter.mjs`, `screenshot.mjs`.

## Ground rules

- **Baseline first, diff after every batch.** For every file in `templates/`,
  `curl` a URL that resolves to it (home, a page, a post, an archive, search,
  404). Save the `<body>` with `?ver=` stripped, every inline `<style id=...>`
  block and a copy of `style.css`. Take the baseline **after** the project's
  PostToolUse formatter has run on any file you touched, or Prettier
  whitespace in `theme.json` will read as a regression. Anything but
  byte-identical output is a regression.
- **Block-comment attributes never render.** `metadata`, `lock` and
  `templateLock` go in by rewriting the JSON inside existing
  `<!-- wp:* {...} -->` comments. Do not rebuild blocks.
- **theme.json `settings` is mostly UI-only, with exceptions that emit CSS.**
  Presets (`color.palette`, `color.gradients`, `spacing.spacingSizes`,
  `typography.fontSizes`, `typography.fontFamilies`, `shadow.presets`) emit
  CSS custom properties; `layout.contentSize` and `layout.wideSize` emit
  layout rules; `spacing.blockGap: false` stops block-gap CSS. Leave all of
  those alone. Only switch off the `custom*` toggles, `appearanceTools`, the
  feature toggles listed in audit item 9 and per-block overrides. Keep
  `"blockGap": true` when turning `appearanceTools` off.
- **Editor-only CSS goes in its own file** loaded through
  `add_editor_style( array( 'style.css', 'assets/css/editor.css' ) )`. Never
  add editor fixes to `style.css`, even scoped to `.editor-styles-wrapper`;
  the file bytes are part of the front end. Block themes get
  `editor-styles` support automatically, so no `add_theme_support()` call.
- **PHP curation lives in one file**, `inc/editor-curation.php`, required from
  `functions.php`. Prefix every function with the theme prefix.
- **Stop after the audit.** Present the fix list and wait for approval before
  applying anything.
- **Never report done without the verify section.** Measure; do not eyeball.

## Phase 1: Audit (read-only)

Report pass / fail / partial per item, naming the file and line.

1. **Editor styles.** `add_editor_style()` loads the same CSS the front end
   loads plus `assets/css/editor.css`. Per-block stylesheets, if any, use
   `wp_enqueue_block_style()` so they load in both contexts.
2. **Root padding.** `settings.useRootPaddingAwareAlignments: true` with root
   `styles.spacing.padding`. Changing this alters front-end markup
   (`has-global-padding`), so if the theme has it off, leave it and record
   the decision.
3. **Styling source.** Styling lives in theme.json where it can. List every
   front-end-only CSS rule that will mismatch in the editor, using
   `references/editor-dom-differences.md` as the checklist. Derive the
   margin list mechanically: every bare `.class` selector in `style.css`
   that sets `margin*`.
4. **Section labels.** Every wrapper in templates, parts and patterns has a
   `metadata.name` a client understands ("Hero", "Services grid", "Footer
   CTA"). Zero "Group", "Cover", "Columns" or "Row" at the top level of List
   View. Pattern resolution overwrites the root block's `metadata.name` with
   the pattern `Title`, so name the pattern what the section should be called.
5. **Locking.** Section wrappers carry `"templateLock":"contentOnly"`. Fixed
   inner blocks carry `"lock":{"move":true,"remove":true}`.
6. **Template parts.** Every `theme.json` `templateParts` entry has `area`
   and a plain-English `title`. Templates have titles in `customTemplates`
   where they're user-selectable.
7. **Patterns.** Every pattern file has `Title`, `Description` and
   `Categories`. Custom categories are registered with
   `register_block_pattern_category()` and plain-English labels ("Page
   Sections", not "Headers"). `remove_theme_support( 'core-block-patterns' )`
   unless core patterns fit the design. Pattern headers are cached in a
   `wp_theme_files_patterns*` transient until the theme version changes;
   delete it after editing headers.
8. **Repeated components.** Cards, CTAs and anything with per-instance
   content: decide between static blocks (content-only locked), a synced
   pattern with overrides, or a custom post type. Synced patterns move content
   into the database; say so in the report.
9. **Control curation in theme.json.** `appearanceTools: false`, then turn
   off: border, `color.custom`, `color.customGradient`, `color.customDuotone`,
   `typography.customFontSize`, `typography.textTransform`,
   `typography.textDecoration`, `typography.textColumns`,
   `typography.writingMode`, `spacing.customSpacingSize`, `spacing.padding`,
   `spacing.margin`, `dimensions`, `position.sticky`, `layout.allowEditing`
   and `layout.allowCustomContentAndWideSize`. Then per-block
   `settings.blocks` overrides for anything with one fixed treatment. Presets
   stay (see ground rules).
10. **Inserter allowlist.** `allowed_block_types_all` restricts blocks to what
    the design uses plus `core/block`, `core/missing`, `core/pattern` and
    `core/template-part`. Posts may get long-form extras (quote, embed,
    table, video, code). Unused block styles: server-registered ones via
    `unregister_block_style()`; core's client-side ones (outline, fill,
    rounded) via `wp.blocks.unregisterBlockStyle` in a script on
    `enqueue_block_editor_assets`.
11. **Lock permission.** `block_editor_settings_all` sets `canLockBlocks` to
    `current_user_can( 'manage_options' )`.
12. **Default page template (optional, recommend it).** On `init`, set
    `template` and `template_lock` on the `page` post type object so a new
    page opens with the main sections in place instead of a blank canvas.
    `template_lock => 'insert'` lets users edit and reorder but not add or
    remove sections; `false` if they need a free canvas below the fixed
    sections.
13. **Iframe integrity.** Confirm nothing de-iframes the post editor: every
    registered block (theme and plugins) declares `apiVersion` 3. One v2
    block puts the whole post editor back in the legacy non-iframed mode and
    editor styles stop matching.

End the audit with a prioritized fix list, an estimate of which items touch
block markup, and any item where you're unsure the change is front-end safe.
Then stop and wait for approval.

## Phase 2: Apply

Work in batches by audit item. After each batch:

1. Let the PostToolUse hook format what you edited; read its output and fix
   what phpcs/eslint could not.
2. Validate `theme.json` against its `$schema` (`npx ajv-cli validate` or the
   project's lint task).
3. Re-run the baseline diff. Stop on any difference.

Editor-only CSS fixes come from `references/editor-dom-differences.md`. If a
mismatch isn't covered there, measure it, fix it in `editor.css`, and add the
entry to the reference with the WP version.

## Phase 3: Verify

Headless Playwright only. Mint cookies with `scripts/mint-cookies.sh` (WP-CLI
`wp_generate_auth_cookie` for the existing admin: `auth` on `/wp-admin` and
`/wp-content/plugins`, `logged_in` on `/`). The Chrome extension freezes on
the Site Editor canvas; do not use it here. Everything writes to `.verify/`
(gitignored).

1. **Front end.** `scripts/screenshot.mjs` at 1440: viewport and full page,
   one per template.
2. **Site Editor.** Same template, same width, settings sidebar closed so the
   canvas is 1440. `scripts/measure.mjs` takes `getBoundingClientRect()` for
   each key element inside `iframe[name="editor-canvas"]` and diffs it
   against the front end. Everything within 3px, page height within a few px.
   Fix in `editor.css`, re-measure. Repeat until clean.
3. **Post editor.** Create a draft page (from the default template if item 12
   was applied, otherwise insert the main pattern). Confirm
   `iframe[name="editor-canvas"]` exists; if it doesn't, find the v2 block
   and report it. Run `measure.mjs` here too.
4. **List View.** `scripts/dump-listview.mjs` opens Document Overview,
   selects the last section so the tree expands, and dumps
   `[role="treegrid"] [role="row"]` levels and text. Top level and section
   level must read as client-facing names.
5. **Locks.** `scripts/check-locks.mjs` runs `selectBlock` on a section, then
   reads `canMoveBlock`, `canRemoveBlock` and `getBlockEditingMode` for the
   section and a heading inside it. Expect `contentOnly`, `false`, `false`.
   Toolbar shows no move or drag controls; inspector shows a Content list and
   no Styles tab.
6. **Inserter.** `scripts/dump-inserter.mjs` dumps
   `.block-editor-block-types-list__item-title` and the Patterns tab
   categories. Only the allowlist and the theme's categories.
7. **Lock permission.** Apply `block_editor_settings_all` via WP-CLI as user
   1 and as user 0. Expect `true` then `false`.
8. **Baseline.** Run the front-end diff one last time.

## Report

One entry per verify step: screenshot or JSON path in `.verify/`, what still
differs, why, and whether it's a WP-version behaviour to add to the reference.
Do not narrate code changes; the diff covers that.
