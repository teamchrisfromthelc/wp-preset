<!-- Part of the figma-to-wordpress skill - loaded on demand. The decision spine lives in ../SKILL.md; this file is reference detail, read when relevant. -->

# Tool reference (deep)

### LocalWP - https://localwp.com/
- Free local WordPress dev environment by Flywheel.
- **Live Link** feature generates a temporary public URL via Cloudflare tunnel - best way to demo work to a client without deploying.
- Per-site MySQL socket at `~/Library/Application Support/Local/run/<SITE_ID>/mysql/mysqld.sock`.
- Bundled binaries: `mysql`, `mysqldump`, `php` in `/Applications/Local.app/Contents/Resources/extraResources/lightning-services/`.

### All-in-One WP Migration (AIOWPM)
- Free. Import limit is enforced by PHP `upload_max_filesize` - raise it (php.ini.hbs in LocalWP; `.user.ini` on a cPanel/DirectAdmin host) and the limit goes away.
- **live → local** is the safe default (pulling a live site down).
- **local → live** is the deploy direction - it OVERWRITES the destination DB, which is exactly what you want for a fresh install. AIOWPM's free **"Restore"** (Backups tab) is PAYWALLED; use **Import → File** instead. Full deploy procedure: see "Going live" section below.

### Figma MCP - https://mcp.figma.com/mcp
- Setup: `claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp`
- OAuth: call `mcp__figma__authenticate`, user clicks URL, paste callback if needed.
- Key tools:
  - `get_metadata` - page/frame structure (XML tree). Always call with just fileKey first to list pages.
  - `get_design_context` - React+Tailwind code + asset URLs. Use `excludeScreenshot: true` to save context tokens.
  - `get_screenshot` - short-lived PNG URL of any node.
  - `get_variable_defs` - design tokens (often empty if Figma file doesn't define variables).
- Asset URLs expire after 7 days. Re-fetch via MCP if needed.

### Figma REST API - https://api.figma.com/v1
- Setup + endpoints: see "Figma REST API" section near the top of this doc.
- Use for: batched SVG export, photo extraction, connectivity check, style/token dumps.
- Auth: `X-Figma-Token: $FIGMA_PAT` header, read-only scopes.
- Complements (doesn't replace) the MCP - see MCP-vs-REST table in that section.

### Playwright (for headless screenshots + JS interaction testing)
- Install Chromium: `npx playwright install chromium`
- Binary path: `~/Library/Caches/ms-playwright/chromium_headless_shell-NNNN/chrome-headless-shell-mac-x64/chrome-headless-shell`
- **For screenshots only:** use the binary directly (no `npm install` needed): `<binary> --headless=new --disable-gpu --hide-scrollbars --no-sandbox --window-size=W,H --screenshot=PATH URL`. Add `--full-page` for full-page (Chrome 116+).
- **For JS interaction testing** (clicking buttons, evaluating `getBoundingClientRect`, verifying state after pagination/tab clicks, etc.): you need the full Node package, NOT just the binary. From the dir you're running the test script in:
  ```bash
  cd /tmp && npm install playwright   # or playwright-core for smaller install
  ```
  Without this, `require('playwright')` errors with `Cannot find module 'playwright'`. The bundled chromium binary is enough for `--screenshot`, but `page.click()` / `page.evaluate()` / `page.waitForTimeout()` need the Node bindings.
- The Playwright MCP itself requires Chrome.app installed (sudo) - bypass by using the chromium_headless_shell binary directly OR the npm-installed `playwright` package from a Node script.

### Safe SVG (WordPress plugin) - INSTALL EARLY

**Install Safe SVG by 10up at the same time as the other plugins (Astra, Elementor, page builders).** WordPress blocks SVG uploads by default for security reasons - without Safe SVG (or another SVG enabler) the user will hit a wall the moment they try to upload any icon SVG via the Media Library, which is mid-build and annoying. Pre-install to avoid the interruption.

- Plugin slug: `safe-svg`, author: 10up. Free, hosted on the WordPress.org repo, ~1M active installs, actively maintained.
- Sanitizes SVGs (strips `<script>` tags and malicious attributes) so client sites stay safe.
- After activation, SVG works in Media Library, Elementor's SVG widget, Astra Header Builder image picker, etc.
- Alternative for local-only dev: Elementor → Settings → Advanced → "Enable Unfiltered File Uploads". Skips sanitization. Don't use on live sites.
- Direct file copies to `wp-content/uploads/` (via shell or filesystem) work without Safe SVG - you're bypassing the Media Library. Useful for batch asset extraction (see Figma REST API section above), but the user can't pick those files in Elementor's picker until they're also in the Media Library, which requires Safe SVG.

**Recommended plugin install order for a Figma→WP build:**
1. Theme (Astra free or whichever you're using)
2. Page builder (Elementor / Divi / Bricks)
3. Page builder companions (UiChemy WordPress side, etc.)
4. **Safe SVG** ← do this NOW, not when you first need an SVG
5. Forms plugin if needed (WPForms Lite)
6. Directory/listing plugin if needed (Business Directory Plugin by Strategy11, etc.)

**Field note:** hitting the SVG upload wall mid-build (when you first try to add an icon via the Media Library) is a classic time-sink - install Safe SVG up front so it never interrupts you.

### LiteSpeed Cache
- Common WP perf plugin. Pre-installed on many hosts.
- **Deactivate during code-gen development** - interferes with the iteration loop.
- Reactivate before going live.

---
