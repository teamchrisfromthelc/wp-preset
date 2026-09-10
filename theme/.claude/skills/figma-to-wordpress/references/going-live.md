<!-- Part of the figma-to-wordpress skill - loaded on demand. The decision spine lives in ../SKILL.md; this file is reference detail, read when relevant. -->

# Going live: deploy a LocalWP build to a DirectAdmin host

A repeatable LocalWP → DirectAdmin launch playbook. Order matters; each gotcha below costs a real debugging loop if skipped.

## Pre-flight
- **Back up the OLD live site first** (host backup tool → download the `.tar.gz` to the Mac, and VERIFY the download finished). `.tar.gz` is a safe archive format. Never empty a docroot until the backup is on the local machine.
- Confirm an **SSL cert exists for the BARE domain** (not just www).
- Never enter the user's host/FTP/DB passwords yourself - give the user the command/field and let them type it.

## 1. Fresh WordPress install (Installatron / DirectAdmin)
- Install on the **bare domain, not www** - www often has no DNS record / no cert SAN → Installatron's test 404s.
- **DirectAdmin docroot trap:** Installatron's HTTPS pre-install test writes a `deleteme.*.php` to `private_html`, but the served HTTPS docroot is actually `public_html` → "not accessible … [404]". **Fix: install on `http://` (bare) instead** - the HTTP docroot IS `public_html`, so the test passes; WP lands in `public_html`, which also serves on https (both gave 403 from the same empty dir = shared docroot). Flip to https *after* (step 4). Alternative: ask the host to symlink `private_html → public_html` (single docroot).
- **Installatron randomizes the table prefix** (e.g. `abcd_`), NOT `wp_`. Any later phpMyAdmin SQL must use the real prefix.

## 2. Export from LocalWP
- AIOWPM → Export → **File** → `.wpress` (lands in `wp-content/ai1wm-backups/` and Downloads). A ~480MB site ≈ 430MB `.wpress`.

## 3. Get the `.wpress` onto the host, then Import (the free-tier reality)
- **AIOWPM free "Restore" (Backups tab) is PAYWALLED. Use Import → File** (free, same result). So you do NOT need to FTP the file into `ai1wm-backups/` - that only helps the paid Restore. (If you ever do need direct placement: `curl --ssl -u USER -T file.wpress "ftp://HOST/domains/<domain>/public_html/wp-content/ai1wm-backups/"` - has NO size cap; user types their own password at the curl prompt. DirectAdmin FTP host = the server hostname, port 21, user = the account user.)
- **Import is gated by PHP `upload_max_filesize`** ("Your host restricts uploads to 64MB"). **DirectAdmin's File Manager web upload also caps ~64MB** - too small for the `.wpress`.
- **Raise the limit with a `.user.ini`** in `public_html` (create it via File Manager - it's tiny, well under 64MB):
  ```ini
  upload_max_filesize = 512M
  post_max_size = 512M
  memory_limit = 512M
  max_execution_time = 600
  max_input_time = 600
  ```
  PHP-FPM caches `.user.ini` ~3-5 min (`user_ini.cache_ttl`); wait, then reload AIOWPM **Import → File** - it should now show 512MB. Select the `.wpress` from the Desktop → it chunk-uploads (reliable, no timeout).
- After import you're logged out. Live admin creds are now the **LOCAL site's** username + password. If unknown, reset via phpMyAdmin:
  ```sql
  UPDATE <prefix>_users SET user_pass = MD5('NewPass2026') WHERE user_login = 'Admin';
  ```
  WP accepts a bare MD5 hash and upgrades it on first login. **phpMyAdmin login = the MySQL `DB_USER`/`DB_PASSWORD` from the live `wp-config.php`** (e.g. `dbuser_xxxx`), NOT the DirectAdmin account user - read them from `public_html/wp-config.php`.

## 4. Post-import must-dos (in this order)
1. **Flush permalinks:** Settings → Permalinks → Save (else every inner page 404s).
2. **HTTPS:** install **Really Simple SSL** → **Activate SSL** (sets site/home URLs to https, adds the http→https redirect, runtime-rewrites mixed content).
3. **Elementor unstyled-content fix:** after migration, some Elementor CSS files (`uploads/elementor/css/base-desktop.css`, `local-<id>-frontend-desktop/mobile.css`) are referenced over **http**. Browsers **block http stylesheets on an https page** → page CONTENT renders raw/unstyled while the Astra header/footer (loaded https) look fine. RSSL (step 2) fixes it immediately at runtime; then bake it in permanently via **Elementor → Tools → "Clear Files & Data"** (Elementor 7 renamed it from "Regenerate Files & Data"). Symptom to recognize: "header+footer styled, everything between is full-size icons + unstyled text."
4. **Search visibility:** Settings → Reading → UNcheck "Discourage search engines" (fresh/dev installs often ship it ON → site stays out of Google).
5. **Email (almost always needed):** fresh hosts' PHP `mail()` silently drops or spam-files form mail. Install **WP Mail SMTP** (free) and send via a **same-domain mailbox** created in DirectAdmin (e.g. `noreply@<domain>`):
   - Mailer: **Other SMTP**; Host: the server the host shows (e.g. `mail.yourhost.tld`); **SSL / port 465**; Auth ON; Username = the full mailbox; **From Email = the mailbox + Force From Email ON** (SPF-aligned → lands in inbox).
   - Test via WP Mail SMTP → **Tools → Email Test** (it's under the **Tools** submenu, NOT a top tab).
   - To verify a contact form without the client's inbox: temporarily point the form's notification "Send To" to your own email, submit, confirm, then switch it back.
6. **Complianz:** re-run its scan on the live domain.
7. **Trash junk pages:** WP's default "Sample Page", plus any leftover build pages that aren't in the menu and aren't the front page (check `page_on_front`). Trash is reversible; only "Delete Permanently" isn't.

## Traps that cost real time
- **LocalWP can hold MULTIPLE sites' DBs in one mysql instance, each DB named `local`.** `ls run/*/mysql/mysqld.sock | head -1` may grab the WRONG site → you read another project's pages and draw false conclusions. ALWAYS match the socket by content first: loop the sockets and `SELECT COUNT(*) … WHERE post_title IN ('<known live page titles>')`; use the socket that returns hits. (Field note: grabbing the wrong site's DB this way - wrong prefix, wrong pages - is an easy and real mistake.)
- **Test forms/email on the LIVE URL, not localhost.** A "form is broken" report turned out to be the user submitting on the local site. Confirm the URL bar before debugging.
- The bundled `mysql` needs `--default-character-set=utf8mb4` for any write touching non-ASCII / accented text, or you get mojibake (e.g. `Ä…` where an accented character should be).

---
