# General Figma → WordPress gotchas catalog (builder-agnostic)

Hard-won knowledge that applies to **any** target builder (Divi, Elementor, Astra, Gutenberg). The main `SKILL.md` points here when a symptom matches. Per-builder tips live in `builders/elementor.md`, `builders/gutenberg.md`, and `builders/divi.md`.

Numbers are stable IDs - never renumber; append new ones at the end.

---

6. **Image URL pointing to wrong domain on LocalWP.**
   Symptom: Logo/icons broken (404) in the headless screenshot.
   Cause: WP siteurl = `http://localhost:NNNNN`, but you used `http://sitename.local/...` (which resolves but to port 80 with no server).
   Fix: Use relative URLs (`/wp-content/...`) in all CSS and shortcodes.

7. **SVG with .png extension.**
   Symptom: Image returns 200 OK but doesn't render in browser.
   Cause: Browsers refuse mismatched MIME types.
   Fix: `file path/to/icon.png` to check actual format; rename to `.svg` if needed.

11. **Headless Chrome wants Google Chrome.app and you don't have it.**
    Symptom: `Chromium distribution 'chrome' is not found`.
    Fix: Use Playwright's bundled chrome-headless-shell binary directly instead of going through the MCP. Path: `~/Library/Caches/ms-playwright/chromium_headless_shell-NNNN/chrome-headless-shell-mac-x64/chrome-headless-shell`. Use the binary directly with `--headless --screenshot=PATH URL`. No sudo required.

12. **LocalWP socket path is per-site (random ID).**
    Symptom: Hardcoded path from a previous project doesn't work.
    Fix: `find ~/Library/Application\ Support/Local/run -name "mysqld.sock"` to find the active socket.

13. **Font weights not loading.**
    Symptom: Set font-weight: 700 but text looks Regular.
    Cause: Custom fonts loaded via `@import` need explicit weights in the URL: `wght@400;500;600;700;800`. If you only import 400, weight 700 falls back to 400.
    Fix: Update the `@import` URL in Theme Options CSS to include all needed weights.

15. **LiteSpeed Cache re-caching pages.**
    Symptom: New changes invisible until force-refresh.
    Fix: Deactivate LiteSpeed Cache plugin during development. Reactivate before going live.

19. **`INSERT INTO wp_posts` fails with "Field 'post_excerpt' doesn't have a default value".**
    Symptom: Creating a new layout post (e.g. `et_footer_layout`) via raw SQL `INSERT` errors out on `post_excerpt`, then on `to_ping`, `pinged`, `post_content_filtered` if you fix them one at a time.
    Cause: WordPress's `wp_posts` table declares these `TEXT NOT NULL` with no default. The WP API auto-fills them as empty strings; raw SQL doesn't.
    Fix: Always include all four NOT-NULL-no-default columns explicitly in your `INSERT`:
    ```sql
    INSERT INTO wp_posts (post_author, post_date, post_date_gmt, post_content, post_title,
      post_excerpt, post_status, comment_status, ping_status, post_name,
      to_ping, pinged, post_content_filtered, post_modified, post_modified_gmt, post_type)
    VALUES (1, NOW(), UTC_TIMESTAMP(), '', 'Global Footer', '', 'publish', 'closed', 'closed',
      'global-footer', '', '', '', NOW(), UTC_TIMESTAMP(), 'et_footer_layout');
    ```
    Same applies for new `et_header_layout`, `et_template`, `et_theme_builder`, `nav_menu_item`, etc.

20. **CSS `background` shorthand with `!important` silently nukes `background-image` in the same rule.**
    Symptom: A button has both a brand background color AND an icon background-image. The color paints fine; the icon never appears. No CSS error, no 404 - `background-image` just renders as `none`.
    Cause: `background: #307bff !important;` is shorthand and resets *all* background sub-properties to initial. The `!important` carries to every sub-property including `background-image`. A subsequent `background-image: url(...)` (without `!important`) loses the specificity war and is silently overridden.
    Fix: Never combine `background:` shorthand with `background-image` in the same rule. Use longhand for both, AND mark every background-* property `!important` if anything in the cascade above sets it that way:
    ```css
    .btn-phone {
      background-color: #307bff !important;
      background-image: url('/path/to/icon.svg') !important;
      background-repeat: no-repeat !important;
      background-position: 22px center !important;
      background-size: 16px 16px !important;
    }
    ```
    Detection: `curl -s "$SITE_URL/<PATH>/" | grep -oE '\.your-button[^{]*\{[^}]*\}'` and verify both `background-color` and `background-image` are present (not `background:` shorthand).

21. **Figma MCP returns PNG only - no SVG export.**
    Symptom: User asks for "vectors from Figma" but you can only deliver raster images.
    Cause: `mcp__figma__get_screenshot` returns PNG. The asset URLs returned by `mcp__figma__get_design_context` (named like `imgVector` or `imgRectangle3`) ALSO return PNG even though the name suggests SVG - Figma rasterizes vector content for the MCP pipeline. There is no SVG export tool in the official Figma MCP as of 2026-05.
    Workarounds:
    - For UI icons: hand-write equivalent SVG (Heroicons-style outlines) - fastest, perfect scaling, ~500B each, but you're approximating not matching pixel-exactly.
    - For Figma-exact icons: `get_screenshot` on the icon's container node at native dimensions gives PNG with transparency and the right shape. Acceptable at 1× / 2× display.
    - For true SVG: user exports manually from Figma desktop (right-click frame → Copy/Paste as → SVG) and provides the file.
    - **Best:** use the **Figma REST API** `/v1/images?ids=...&format=svg` for batched true-SVG export. See `references/figma-rest.md`. Only fall back to PNG when the API returns `null` (flattened bitmap source) or for genuine raster photos.
    Lesson: when extracting design tokens from `get_design_context`, treat `const imgVector = "..."` URLs as PNG, not SVG.

22. **Hand-drawn icon approximations get vetoed in design review.**
    Symptom: You wrote a Heroicons-style outline SVG for an icon. It renders fine, but in design review the designer says "use the real Figma icons, not your approximations."
    Cause: Even when shape is right, stroke width / corner radius / proportions are subtly off vs the Figma source. Designers notice.
    Fix: First pass with hand-drawn SVG is fine to unblock the build, but plan for a v2 swap to actual Figma exports. Track icon files with a clear naming convention so the swap is mechanical: prefix `icon-fish.svg` (hand-drawn) vs `icon-fish.png` (Figma export at native size). When replacing, just change the file extension in references.
    Best practice: fetch icons via `get_screenshot` on each icon's container node ID from the first iteration. The CONTAINER node renders the composed icon; do NOT try to assemble from `imgGroup1` / `imgGroup2` etc. - those are sub-paths of a single composed icon and won't render correctly alone.

23. **`get_design_context` `imgImage` constants don't always map to the visible image at that position.**
    Symptom: You map `imgImage1` → card 1 because it appears first in the React code, but the rendered card shows a different image than the Figma design.
    Cause: Figma's MCP serializes image variables in a registry-style order that doesn't necessarily match top-to-bottom / left-to-right Z-order of the rendered frame. Two cards may share the same underlying image asset; or `imgImage1` may refer to a node deeper in the tree than expected.
    Fix: Use `mcp__figma__get_metadata` on the parent frame to find each image node's actual ID (e.g. `<NODE_ID>` for card 1's image), then `mcp__figma__get_screenshot` on that exact node. Returns the right pixels at native dimensions every time.
    Workflow:
    ```
    1. get_metadata(parent_frame) → XML tree with all child node IDs
    2. For each rendered image you care about, grep the XML for `name="Image"` or similar
    3. get_screenshot(image_node_id, maxDimension=800) → returns the exact PNG for that node
    ```

24. **Putting `flex: 1 1 auto` on the WRONG column creates ugly empty space when viewport > Figma frame width.**
    Symptom: You build a footer/header from a 1440px Figma frame. At the user's actual 1680px viewport, the design has a big visually-empty gap on the right side - text columns that were nicely positioned in Figma are now anchored too far left.
    Cause: The Figma frame is 1440px. Your viewport is 1680px (or wider). That's 240px+ of "extra" width the layout has to absorb somewhere. The natural instinct is to put `flex: 1 1 auto` on the LAST column so it stretches to fill. But that puts ALL the extra space on the RIGHT - exactly where the eye notices empty whitespace, and exactly where Figma intended content to be.
    Fix: Put the flex-grow on the column where the design actually has whitespace. For most marketing footers, the natural whitespace gap is between the logo (anchored left) and the link-column cluster (anchored right). So:
    ```
    Col 1 (logo):        flex: 1 1 350px;  min-width: 350px;   ← absorbs extra width
    Col 2 (PRODUCTS):    flex: 0 0 236px;  max-width: 236px;
    Col 3 (INFORMATION): flex: 0 0 246px;  max-width: 246px;
    Col 4 (CONTACT):     flex: 0 0 408px;  max-width: 408px;   ← was flex 1 1 auto
    ```
    Verification: pixel-scan the rendered output at multiple viewport widths (1440, 1680, 1920). At 1440 (= Figma frame) the layout should match Figma 1:1. At 1680 the right-edge distances (e.g. "address text is 159px from viewport right") should still match Figma's frame values. The LEFT-edge of the link-cluster shifts right by `(viewport - 1440)` while the logo stays anchored at `x = section_padding_left`.
    General rule: ask "where is the natural whitespace in the design?" then put `flex: 1 1 X` on THAT column. Never default to the last column without checking.

28. **PHP CLI can't reach LocalWP's MySQL because `localhost` doesn't resolve to the right socket.**
    Symptom: Custom `wp-load.php`-based PHP scripts fail with "Error establishing a database connection" even though the site loads fine in the browser and `mysql --socket=...` works.
    Cause: WP's `DB_HOST=localhost` makes PHP's `mysqli_connect` try the DEFAULT unix socket (`/tmp/mysql.sock` on macOS), but LocalWP runs MySQL on a per-site socket under `~/Library/Application Support/Local/run/<SITE_ID>/mysql/mysqld.sock`. The Local-provided Apache/nginx PHP-FPM knows about it via `ini`, the bare CLI doesn't.
    Fix: Invoke PHP with the socket override flag:
    ```bash
    PHP_BIN="$HOME/.../Local/lightning-services/php-8.2.X+0/bin/darwin/bin/php"
    SOCKET="$HOME/.../Local/run/<SITE_ID>/mysql/mysqld.sock"
    "$PHP_BIN" -d mysqli.default_socket="$SOCKET" -d pdo_mysql.default_socket="$SOCKET" your-script.php
    ```
    Now `wp-load.php` will connect successfully because `mysqli_connect('localhost', ...)` resolves through the override socket.
    Simpler alternative: skip `wp-load.php` entirely and connect directly with `new mysqli(null,'root','root','local',0,$socket)` - pass the per-site socket as the 6th arg.

28b. **⚠️ WORST-CASE of #28: with MULTIPLE LocalWP sites running, `find … -name mysqld.sock | head -1` picks a NON-DETERMINISTIC socket → you can seed/migrate the WRONG site's database without noticing.** Every LocalWP site uses `DB_NAME='local'`, so requiring site A's `wp-load.php` while passing site B's socket connects you cleanly to **site B's** `local` DB - no error, wrong data. Field note: this really happens - a seed script grabs another running site's socket and writes CPTs/posts/a page into the wrong site before it's caught, costing a full cleanup pass. Symptoms that something's off: the page title / active plugins / `siteurl` don't match the site you think you're on. PREVENTION, every bootstrap script: (1) **hardcode the exact target socket** (map each site once: `mysql --socket=<each>.sock -uroot -proot local -Ne "SELECT option_value FROM wp_options WHERE option_name='siteurl'"` → which dir = which site), never `head -1`; (2) **guard at the top**: `if (strpos(get_option('siteurl'),'<expected-port>')===false) { exit('WRONG SITE'); }`. The port in `siteurl` is the cheapest unique site fingerprint. (Also note LocalWP can **reassign a site's port** between sessions - re-confirm it; a stale remembered port is why the disambiguation matters.)

29. **LocalWP's host nginx :80 can be blocked by Docker; the per-site nginx still works on a high port.**
    Symptom: `curl http://sitename.local/` times out, but the site opens fine in your browser (because LocalWP intercepts via its router/proxy).
    Cause: LocalWP's router tries to bind :80 to forward `sitename.local` to the per-site nginx. If Docker Desktop or another service already owns :80, the router silently fails to forward. The per-site nginx is still up, listening on a per-site port (e.g., `127.0.0.1:10003`).
    Fix: `lsof -nP -iTCP -sTCP:LISTEN | grep nginx` to find the per-site nginx port (usually 10003+). Then hit it directly with the right Host header:
    ```bash
    curl -L "http://mysite.local:10003/some-page/"   # /etc/hosts maps the .local name to 127.0.0.1; the port is the site's nginx
    ```
    Headless screenshots: use the same URL with the `:10003` port suffix in Playwright. Don't waste time fighting the router.

33. **zsh has a built-in readonly variable named `status`. Assigning to it errors out with `read-only variable: status`.**
    Symptom: `status=$(curl -s -o /tmp/page.html -w "%{http_code}" "$URL")` fails with `(eval):N: read-only variable: status` on macOS.
    Cause: macOS's default interactive shell is zsh, and zsh reserves `$status` as a readonly alias for `$?` (last command's exit status). The Bash tool on macOS sometimes resolves through zsh's variable rules depending on harness configuration.
    Fix: Rename the variable. Conventional choices: `HTTP_CODE`, `STATUS_CODE`, `RC`, `EXIT_CODE`. Same applies to any other zsh-reserved names you might collide with: `path`, `prompt`, `argv`, `dirstack`, `history`, `signals`, `options`, `RANDOM`, `SECONDS`.
    Detection: if a `VAR=$(...)` assignment fails with `read-only variable`, it's this. Renaming is always the right fix - never try `unset` on a zsh readonly, it won't release.

34. **Equal-height sibling cards: reach for CSS Grid + `align-items: stretch`, not flex.**
    Symptom: Two cards side-by-side in a flex container have very different content lengths (e.g., a short list vs. a long one). They render at different heights - the shorter card ends with a stub of background visible below it, the taller card looks attached to its content. Adding `align-items: stretch` to the flex parent helps only if both cards have `height: auto` AND don't have explicit `height` set anywhere in their chain.
    Cause: Flex `align-items: stretch` works on the cross-axis but fights with intrinsic sizing once cards have padding-based content height. Children of flex containers often regress to content-height despite the stretch hint.
    Fix: Use CSS Grid instead. Grid's row implicit height equals the tallest child by default, and `align-items: stretch` is honored cleanly:
    ```css
    .two-card-row {
      display: grid;
      grid-template-columns: 412px 780px;  /* or whatever your widths are */
      gap: 48px;
      align-items: stretch;                /* default but explicit for documentation */
    }
    ```
    Both cards become equal height = max(card1 content, card2 content). Verify with Playwright:
    ```js
    document.querySelectorAll('.card').forEach(c => console.log(c.getBoundingClientRect().height));
    // Both heights should print identical.
    ```
    Bonus pattern: at viewports wider than your design's frame, add `justify-content: center` + a `max-width` to keep the row from anchoring left with dead space on the right (companion to gotcha #24):
    ```css
    .two-card-row {
      max-width: 1240px;
      margin: 0 auto;
      justify-content: center;
    }
    ```
    Now at 1680px the cards stay centered with symmetric margins (220px each side) instead of left-anchored with 340px dead-right.

43. **Planning a multi-page build - enumerate which pages are ACTUALLY designed in Figma before scoping work.**
    Symptom: You assume every nav item has a finished full-page design, scope the build around that, then discover mid-build that some "pages" are just home-page sections or blank stubs awaiting the designer.
    Cause: `mcp__figma__get_metadata` on a whole page frequently **exceeds the token limit** and is saved to a file instead of returned inline. Blindly retrying wastes calls.
    Fix: parse the saved file instead of retrying. To list the designed **page-level screens**, extract top-level `<frame>` nodes with `width >= ~1200` (full-page frames; narrower frames are sections/components/headers). A quick PHP+regex pass over the saved XML yields `id | name | WxH` per screen.
    Cross-check: compare the designed frames against the WP nav-menu pages - any nav item whose target page has empty `_elementor_data` (Elementor) or empty `post_content` (Divi) is a link currently pointing at a blank page. Flag these as the build backlog, not as "done" pages.
    Field note: it's common for a Figma file to have full-page frames for only *some* nav items - the rest are home-page sections or still-unfinished designs. Enumerate before you promise a page count.

49. **"This image looks pixely" → check the SOURCE resolution, not the served `naturalWidth`; and never swap real people for stock.** A WP attachment's `naturalWidth` can lie: an image can report 1440px yet look soft because it was **upscaled from a tiny original** (Figma exported it small). Upscaling adds pixels, not detail.
    Diagnose: compare the *source* dimensions (the Figma export / raster file - `sips -g pixelWidth -g pixelHeight file.png`) against the display size, not just the served pixels. Field note: e.g. headshots can be 1440px in WP but upscaled from a ~162px Figma original → soft in an 81px circle on retina, while a hero (2560px source) and a portrait (1440px source) are genuinely crisp at their display sizes. `naturalWidth=1440` tells you nothing - the tiny source is the truth.
    Options, in order: (1) **Ask the client for the originals** - whoever exported the small version usually has the full-res file. (2) **AI face-upscale** the existing crops (fal.ai GFPGAN / CodeFormer / clarity-upscaler are built for portraits; ~162px → crisp ~600px) - but it *invents* detail and can subtly alter a real face, so get the client/subject to approve before it ships. (3) Accept as-is (162px is borderline-ok at 81px on 1× screens). **Never** replace named real people (board members, staff) with stock portraits or different faces found via web search - that misrepresents the org and a designer/boss catches it instantly. The only valid web source is a *higher-res photo of the same actual person* (e.g. their own LinkedIn), with usage rights.

56. **A global `... !important` override silently loses to a page-scoped `body.page-id-N ...` rule - that rule has higher specificity, and `!important` does not beat specificity.**
    Symptom: You write a global mobile override like `.et-l--post .et_pb_section:last-child{padding-bottom:40px !important}` to fix something on every page, clear cache - and the value is unchanged on a page that has its own responsive rule, even though both use `!important`.
    Cause: `!important` only breaks ties at EQUAL specificity; it never beats higher specificity. `.et-l--post .et_pb_section:last-child` = specificity (0,0,3,0) - three classes/pseudo-classes, zero elements. A page-scoped builder/responsive rule `body.page-id-N .et-l--post .et_pb_section_5` = (0,0,3,1), because `body` adds one element to the count. Higher specificity wins regardless of source order or `!important` on the loser. Divi and Astra both store page-scoped responsive CSS as `body.page-id-N ...`, so a "one rule for all pages" override hits this constantly.
    Fix: raise your global rule's specificity to match (don't over-shoot), then rely on source order - append your block last. Prepending a single `body ` does it: `body .et-l--post .et_pb_section:last-child` = (0,0,3,1), now equal to the page rule, and being later in the stylesheet it wins.
    Detection: in DevTools the winning rule shows at the top of the element's Styles pane with yours struck through; programmatically, `getComputedStyle(el).prop` returns the page value, not yours, even though your rule is present in the cascade. Count specificity by hand: every `body.page-id-N` compound = 1 element (`body`) + 1 class.

67. **AIOWPM migration to a live site running older WP core locks you out - the WP 6.8+ `$wp$` password hash can't be verified by pre-6.8 core.**
    Symptom: you migrate the finished local site to live via All-in-One WP Migration, the import succeeds and the site renders - but you can't log into live wp-admin. Every password is rejected as "incorrect" (a *password* error, not an *unknown username* error), even after resetting the password locally, re-exporting, and re-importing. No password ever works.
    Two things stack to cause it:
    1. **AIOWPM overwrites the users table.** After import, the live login is no longer the old live credentials - it's the LOCAL site's admin username + password (e.g. local default `Admin`). People first hit this thinking their old password "stopped working." (Always know your local admin user/pass before migrating.)
    2. **WordPress 6.8 changed password hashing to bcrypt with a `$wp$2y$` prefix.** AIOWPM imports the DATABASE (which now contains `$wp$` hashes if local is 6.8+) but does **NOT** replace WordPress **core files** - so live keeps whatever (often older) core it had. A pre-6.8 core literally has no code path to verify a `$wp$` hash → the hash never matches → permanent "incorrect password," regardless of what you set.
    Detect: on local, check the admin's `user_pass` prefix (`SELECT user_pass FROM wp_users` or via wp-load). `$wp$2y$...` = new format (the trap if live core is old). `$P$...` = old portable phpass format (universally compatible). Also check `get_bloginfo('version')` locally - 6.8+ means new hashes.
    Fix (no live access needed): set the admin password as an OLD-FORMAT phpass `$P$` hash in the LOCAL db, then re-export + re-import. `$P$` is verifiable by EVERY WP version (6.8+ keeps backward-compat to read it; older core treats it as native), so login works whatever the live core version is:
    ```php
    require ABSPATH.'wp-includes/class-phpass.php';
    $hash = (new PasswordHash(8, true))->HashPassword('NewPass123!'); // true = portable $P$ hash
    $wpdb->update($wpdb->users, ['user_pass'=>$hash], ['ID'=>1]);
    delete_user_meta(1,'session_tokens');   // drop stale sessions
    ```
    Verify the new hash starts with `$P$` and that `wp_check_password()` passes before re-exporting. Then delete old `.wpress` files so you can't re-import a stale one with the bad hash.
    Also: log in via an **incognito window** - the browser/password-manager autofills the *old* live password over what you type and masks the real result.
    Better long-term fix: get live WP core onto 6.8+ too (so `$wp$` works) - but that needs dashboard access you don't have yet, so the `$P$` route is the bootstrap.

68. **A client "logo" PDF/file is often RASTER-mark + vector-text - verify before trusting the SVG-over-PNG rule; if raster, deliver a cropped TRANSPARENT PNG, not an SVG.** The global rule is "SVG for logos/icons," but a vector-looking PDF can be a bitmap mark with only the text as real vector. Check first: `pdf2svg in.pdf out.svg` then `grep -c '<image' out.svg` (embedded rasters) and `grep '<filter' / 'feColorMatrix'` (cairo color-to-alpha = the raster has a baked background). **If it has `<image>`+filters, do NOT upload the SVG** - WP **Safe SVG strips `fe*` filter primitives on upload**, so the mark's transparency dies → white box / invisible mark. Robust pipeline (one-time `brew install pdf2svg librsvg`):
    - `rsvg-convert -z2 logo.svg -o logo.png` → librsvg DOES apply the color-to-alpha filter correctly (transparent mark, no white box) where Safe SVG would have killed it.
    - **Auto-crop** the result to its non-transparent bbox via PHP-GD (scan alpha, find min/max x/y, +pad) - PDF/export pages are mostly empty canvas, so an un-cropped logo renders tiny inside huge margins.
    - **Recolor for a dark background** (e.g. white text on a navy footer) WITHOUT a vector: for a flat horizontal logo (mark left, text right), scan columns for the all-transparent GAP between mark and text, then recolor only the text-side pixels (`x ≥ gap`) to white preserving their alpha - mark untouched.
    - **Limit (be honest with the user):** a transparent region INSIDE a flattened mark can sometimes be flood-filled, but any inner region that OPENS to the outer edge can't be sealed automatically without aggressive morphological close (which bleeds stray marks outside) - so it lands ~95%. **Pixel-perfect recolor/refill of a logo interior needs the VECTOR source** (set the shape's fill) - ask the designer rather than burning rounds on raster surgery.

80. **Importing client content from Word docs into WordPress - three traps: no converter installed, macOS NFD filenames, and "file" fields.** A common task: client hands you `.docx` articles (+ Excel/PowerPoint attachments) to load as Posts/CPT items. What bites:
    - **No `pandoc`/`soffice` on the machine** → can't shell out to convert docx→HTML. Don't flatten to plain text (loses headings + TABLES). Write a small **Python `docx`→HTML parser**: a `.docx` is a zip; parse `word/document.xml` with `xml.etree`, walk `<w:body>` children IN ORDER, emit `<p>` for `<w:p>` (map `<w:pStyle>` containing "Heading"/"Title" → `<h2>/<h3>`; treat an all-bold short paragraph as a heading), and `<table>` for `<w:tbl>` (rows `<w:tr>`, cells `<w:tc>`). Take the first non-empty paragraph as the post title, the rest as body, first real paragraph (trimmed ~200 chars) as the excerpt. Tables then render fine via `the_content()`.
    - **macOS stores non-ASCII filenames in NFD (decomposed) Unicode; a PHP/JS string literal is NFC (composed)** → a map keyed on an accented filename (e.g. `"café-menu.docx"`) MISSES the real key and you get a null lookup. This can silently write a **blank-title post over an existing one**. FIX: never key off the diacritic filename - key off an **ASCII-derived identifier** (e.g. the converter's output `slug.html` name, or `iconv`/normalize both sides first). Also guard inserts against empty title (`if(!$title) skip`) so a miss can't clobber.
    - **A "downloadable file" usually needs no new field/template** - upload the office file to the **Media Library** (`wp_insert_attachment` + `wp_generate_attachment_metadata`; xlsx/pptx MIME are allowed for admins) and append a styled link to the post BODY: `<p><a href="<attachment_url>" download style="color:#<brand>;font-weight:600">…</a></p>`. Browsers download office types regardless; `download` forces it same-origin. Make the importer **idempotent** (upsert by exact title; reuse an attachment whose title == basename) so re-runs don't duplicate.

82. **Writing WordPress "Additional CSS" via PHP CLI silently CORRUPTS it - `wp_update_custom_css_post()` (and any `wp_insert/update_post` on the `custom_css` type) runs the content through KSES, and on CLI there's no logged-in user so `unfiltered_html` is false → it strips/mangles valid CSS (notably `>` child combinators become `&gt;`, chunks vanish).** Field note: appending one rule to Additional CSS via `wp_update_custom_css_post()` in a CLI script can shrink the post (e.g. 22187 → 20912 bytes) - ~1.5KB of the user's EXISTING CSS eaten. **FIX - never round-trip Additional CSS through the post API on CLI.** Either (a) write it raw, bypassing all filters: `$wpdb->update($wpdb->posts, ['post_content'=>$css], ['ID'=>$custom_css_post_id])` (find the id via `wp_get_custom_css_post()->ID`; pass the literal string, do NOT `wp_slash`), or (b) just paste it in the **Customizer → Additional CSS** (runs as the admin, has `unfiltered_html`, no stripping). ALWAYS back up `post_content` first (`wp_get_custom_css()` returns the current value) and verify length grew by ~your addition + `grep -c '&gt;'` is 0 after. (Same root cause as any "I edited content via WP-CLI/cron and it got HTML-filtered" - KSES keys off the current user's caps, which are empty in a bare CLI bootstrap.)

83. **Single-post / plugin-template content that's `max-width`-capped but LEFT-pinned looks broken on wide screens - a narrow text column hugging the left with a huge empty right half - even though the article wrapper itself is full-width-centered.** The fix the client wants ("center it but keep the text left-aligned") is to center the COLUMN, not the text. Measure first (don't eyeball): walk the text element's ancestor chain for the one carrying the `max-width` (e.g. a single-news template that sets `.art-title/.art-lead{max-width:760px}` and `.art-body{max-width:880px}` with `margin:0` inside a full-width `.article` → title at L:78 R:842 on a 1680 screen). **FIX (Additional CSS, responsive-safe):** cap the article wrapper and auto-center it, and release the per-element caps so they fill the centered column - gate to desktop so phones/small tablets (already filling the screen) are untouched:
    ```css
    @media (min-width: 769px) {
      .single .article { max-width: 920px; margin-left: auto; margin-right: auto; }
      .single .art-title, .single .art-lead { max-width: none; }
    }
    ```
    `max-width + margin:auto` is inherently mobile-safe: below the cap the column just fills the viewport, so centering is a no-op there. Full-width hero/CTA bands above/below the reading column stay full-width (different selectors) - a full-width hero + centered reading column is the intended article look. Verify by MEASURING article L/R/W at 1680, ~1024, 390 (centered = equal L/R).
