# Verify scripts spec

Write these once into `scripts/`, test them against the Local site and commit
them. Every run uses the committed scripts; do not rewrite them inline.

Shared conventions:

- Node ESM, Playwright (`npm i -D playwright` at the project root, chromium
  installed).
- Config from env: `SITE_URL`, `COOKIE_FILE` (default `.verify/cookies.json`),
  `OUT_DIR` (default `.verify/`).
- Every script exits non-zero on a failed assertion and writes JSON to
  `OUT_DIR` named after the script and a slug argument, e.g.
  `.verify/measure-home-site-editor.json`.
- Viewport 1440 × 900 unless told otherwise. Disable animations
  (`page.addStyleTag` with `* { transition: none !important; animation: none
  !important }` in both the top document and the canvas iframe).
- Wait for fonts: `await page.evaluate(() => document.fonts.ready)` in the
  canvas iframe as well as the top frame.

## `mint-cookies.sh`

Arguments: `<site-url> <user-id>`. Uses `wp eval` (through `local-wp-mcp` or
the Local shell) to call `wp_generate_auth_cookie( $uid, time() + DAY_IN_SECONDS,
'auth' )` and `'logged_in'`. Writes a Playwright cookie JSON with:

- `auth` cookie name from `AUTH_COOKIE`, path `/wp-admin` and again with path
  `/wp-content/plugins`
- `logged_in` cookie name from `LOGGED_IN_COOKIE`, path `/`

Domain is the site host, `httpOnly: true`, `secure` matches the scheme.

## `screenshot.mjs`

Arguments: `<url> <slug> [--width 1440]`. Loads cookies only if `--admin` is
passed. Writes `<slug>-viewport.png` and `<slug>-full.png`.

## `measure.mjs`

Arguments: `<front-url> <editor-url> <slug> [--selectors file.json]`.

1. Load `<front-url>` at 1440, collect `getBoundingClientRect()` and a fixed
   set of computed styles (`font-size`, `line-height`, `font-family`,
   `color`, `background-color`, `padding-*`, `margin-*`, `gap`) for each
   selector in the selectors file (default: every element with a
   `.wp-block-*` class that has a `metadata.name`, plus `h1..h3`, `p`,
   `.wp-block-button__link`, `img`).
2. Load `<editor-url>` with cookies. Close the settings sidebar if open
   (`wp.data.dispatch('core/edit-site').closeGeneralSidebar()` or the
   editor-post equivalent), wait for `iframe[name="editor-canvas"]`.
3. Collect the same data inside the iframe via `frameLocator`.
4. Diff per selector. Tolerance 3px on rect values, exact match on colors and
   font-family, 1px on font-size. Page height compared with 8px tolerance.
5. Print a table of misses and exit 1 if any.

If the iframe is missing, exit 2 with the list of blocks reporting
`apiVersion < 3`.

## `dump-listview.mjs`

Arguments: `<editor-url> <slug>`. With cookies: open Document Overview
(`wp.data.dispatch('core/editor').setIsListViewOpened(true)`), select the last
top-level block programmatically so the tree expands, then dump every
`[role="treegrid"] [role="row"]` with its `aria-level` and text. Assert no
top-level or level-2 row text is in the generic set (`Group`, `Row`, `Stack`,
`Grid`, `Cover`, `Columns`, `Column`).

## `check-locks.mjs`

Arguments: `<editor-url> <section-client-id-or-name> <slug>`. With cookies:
resolve the section by `metadata.name`, `selectBlock` it, then read from
`core/block-editor`: `getBlockEditingMode`, `canMoveBlock`, `canRemoveBlock`
for the section and for the first heading inside it. Assert `contentOnly`,
`false`, `false` on the section. Assert the toolbar has no
`.block-editor-block-mover` and the inspector has no tab labelled Styles.
Screenshot the toolbar and inspector.

## `dump-inserter.mjs`

Arguments: `<editor-url> <slug> [--allowlist file.json]`. With cookies: open
the inserter, dump `.block-editor-block-types-list__item-title` text, switch
to the Patterns tab and dump category names. Assert every block title maps to
an entry in the allowlist and every category is in the theme's registered
set.
