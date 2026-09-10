<!-- Part of the figma-to-wordpress skill - loaded on demand. The decision spine lives in ../SKILL.md; this file is reference detail, read when relevant. -->

## Find your environment paths (do this once at session start)

**Fastest: `bash scripts/env-detect.sh --url localhost:PORT`** - it does everything below in one shot (php/mysql/mysqldump/chromium/node + `$FIGMA_PAT`), matches the correct LocalWP socket when multiple sites run, and writes a sourceable `~/.cache/fig2wp/env.sh` (`source` it to get `$PHP $MYSQL $MYSQLDUMP $CHS $NODE $UZ_SOCK`). The manual commands below are the fallback / reference for what it detects.

```bash
# LocalWP MySQL socket (changes per site - find the right one)
find ~/Library/Application\ Support/Local/run -name "mysqld.sock" 2>/dev/null

# LocalWP's bundled MySQL binary
ls /Applications/Local.app/Contents/Resources/extraResources/lightning-services/mysql-*/bin/darwin*/bin/mysql

# LocalWP's bundled PHP CLI
ls /Applications/Local.app/Contents/Resources/extraResources/lightning-services/php-*/bin/darwin/bin/php

# LocalWP's bundled mysqldump (for DB snapshots)
ls /Applications/Local.app/Contents/Resources/extraResources/lightning-services/mysql-*/bin/darwin*/bin/mysqldump

# Playwright's bundled Chromium (for headless screenshots - no sudo needed)
find ~/Library/Caches/ms-playwright -name "chrome-headless-shell" -type f 2>/dev/null

# Site URL (LocalWP usually serves on localhost:NNNNN, port varies per site)
# Check wp-admin URL in browser OR query DB:
# SELECT option_value FROM wp_options WHERE option_name='siteurl';
```

Save these to working memory at the start of the session - you'll reuse them dozens of times.
