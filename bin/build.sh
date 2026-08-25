#!/usr/bin/env bash
# build.sh — package the plugin or theme as an installable zip.
#
#   composer build          -> dist/<slug>-<version>.zip
#   composer build -- --dev -> skip the npm production build (faster iteration)
#
# The zip contains a single top-level <slug>/ directory, which is what
# WordPress requires when installing from a file. Plugin or theme is detected
# from the headers; everything else is identical for both.
#
# Excludes dev tooling; includes only what the project needs at runtime. If
# composer.json declares runtime dependencies, vendor/ is reinstalled with
# --no-dev into the staging copy so dev packages never ship.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

SKIP_ASSETS=0
[ "${1:-}" = "--dev" ] && SKIP_ASSETS=1

# Metadata comes from the project's own headers, not the directory name — a
# checkout folder is often named differently (or is a temp/CI path), and the
# slug decides the zip's top-level directory.
#
# A plugin declares "Plugin Name:" in a PHP file; a theme declares "Theme Name:"
# in style.css. Everything after this block is identical for both.
KIND=plugin
# `|| true` matters: with set -euo pipefail, a grep that matches nothing fails
# the pipeline and aborts the script silently. Finding no plugin file is a
# normal outcome here — it means this is a theme.
MAIN=$(grep -ilm1 --include='*.php' --exclude-dir=vendor --exclude-dir=node_modules \
	--exclude-dir=tests --exclude-dir=dist -r 'Plugin Name:' "$ROOT" 2>/dev/null \
	| sort | head -1 || true)

if [ ! -f "$MAIN" ] && grep -qs 'Theme Name:' "$ROOT/style.css"; then
	KIND=theme
	MAIN="$ROOT/style.css"
fi

if [ ! -f "$MAIN" ]; then
	{
		echo "error: no plugin or theme found in $ROOT."
		echo "Expected a PHP file with a 'Plugin Name:' header, or a style.css"
		echo "with a 'Theme Name:' header."
	} >&2
	exit 1
fi

SLUG=$(grep -m1 -E '^[[:space:]]*\*?[[:space:]]*Text Domain:' "$MAIN" \
	| sed -E 's/.*Text Domain:[[:space:]]*//' | tr -d '[:space:]')
if [ -z "$SLUG" ]; then
	# A theme without a Text Domain falls back to its directory name, which is
	# what WordPress uses as the theme slug anyway.
	[ "$KIND" = theme ] && SLUG=$(basename "$ROOT") || SLUG=$(basename "$MAIN" .php)
fi

VERSION=$(grep -m1 -E '^\s*\*?\s*Version:' "$MAIN" | sed -E 's/.*Version:[[:space:]]*//' | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
	echo "error: no 'Version:' header in $(basename "$MAIN")." >&2
	exit 1
fi

# The header is what WordPress reads, but code reads the constant, so a stale
# constant ships a plugin that reports one version and behaves as another.
# Fail rather than warn: a warning scrolls past and the zip still gets shipped.
# Plugins that define no constant are unaffected.
# A plugin defines its constant in the main file; a theme defines it in
# functions.php, since style.css holds only the headers.
CONST_FILE="$MAIN"
[ "$KIND" = theme ] && CONST_FILE="$ROOT/functions.php"

CONST_VERSION=""
[ -f "$CONST_FILE" ] && CONST_VERSION=$(sed -nE "s/.*define\([[:space:]]*'[A-Z_]+_VERSION'[[:space:]]*,[[:space:]]*'([^']+)'.*/\1/p" "$CONST_FILE" 2>/dev/null | head -1 || true)

if [ -n "$CONST_VERSION" ] && [ "$CONST_VERSION" != "$VERSION" ]; then
	{
		echo "error: version mismatch."
		echo "  $(basename "$MAIN")"
		echo "    Version: header   $VERSION"
		echo "  $(basename "$CONST_FILE")"
		echo "    *_VERSION const   $CONST_VERSION"
		echo "Update both to the same value, then build again."
	} >&2
	exit 1
fi

DIST="$ROOT/dist"
STAGE="$DIST/.stage/$SLUG"
ZIP="$DIST/$SLUG-$VERSION.zip"

echo "Building $KIND $SLUG $VERSION"

# Front-end assets first: they must exist before staging copies them.
# wp-scripts exits 0 and creates an empty build/ even when there is nothing to
# compile, so only run it when there is actually a source directory.
if [ "$SKIP_ASSETS" = "0" ] && [ -d "$ROOT/src" ] && [ -f "$ROOT/package.json" ] \
	&& grep -q '"build"' "$ROOT/package.json"; then
	if [ -d "$ROOT/node_modules" ]; then
		echo "  building assets..."
		npm run build --silent
	else
		echo "  warning: node_modules missing — skipping asset build. Run 'npm install' first." >&2
	fi
fi

rm -rf "$DIST/.stage" "$ZIP"
mkdir -p "$STAGE"

# rsync's exclude list is the single source of truth for what ships.
#
# Paths are ANCHORED with a leading slash so they only match at the project
# root. Unanchored, 'src/' would also strip vendor/psr/log/src and silently
# ship a plugin whose autoloader points at files that aren't there.
echo "  staging files..."
rsync -a \
	--exclude '/.git/' \
	--exclude '/.github/' \
	--exclude '/.claude/' \
	--exclude '/CLAUDE.md' \
	--exclude '/AGENTS.md' \
	--exclude '/dist/' \
	--exclude '/node_modules/' \
	--exclude '/src/' \
	--exclude '/tests/' \
	--exclude '/bin/' \
	--exclude '/.editorconfig' \
	--exclude '/.gitignore' \
	--exclude '/.prettierignore' \
	--exclude '/.prettierrc.js' \
	--exclude '/.wp-env.json' \
	--exclude '/.wp-env.override.json' \
	--exclude '/eslint.config.mjs' \
	--exclude '/package.json' \
	--exclude '/package-lock.json' \
	--exclude '/phpcs.xml*' \
	--exclude '/phpstan.neon*' \
	--exclude '/phpunit*.xml*' \
	--exclude '/.phpunit.result.cache' \
	--exclude '/.phpcs-cache' \
	--exclude '*.map' \
	--exclude '.DS_Store' \
	"$ROOT/" "$STAGE/"

# Runtime dependencies only. If the plugin has none, drop vendor/ entirely
# rather than shipping an autoloader for nothing.
# "require" minus the php/ext-* platform entries. A grep can't do this
# reliably across lines, so parse the JSON.
HAS_RUNTIME_DEPS=0
if [ -f "$ROOT/composer.json" ] && command -v php >/dev/null 2>&1; then
	HAS_RUNTIME_DEPS=$(php -r '
		$f = $argv[1];
		$j = json_decode(file_get_contents($f), true);
		$r = is_array($j) && isset($j["require"]) ? $j["require"] : [];
		foreach (array_keys($r) as $k) {
			if ($k !== "php" && strpos($k, "ext-") !== 0) { echo "1"; exit; }
		}
		echo "0";
	' "$ROOT/composer.json" 2>/dev/null || echo 0)
fi

if [ "$HAS_RUNTIME_DEPS" = "1" ]; then
	echo "  installing production dependencies..."
	cp "$ROOT/composer.json" "$STAGE/composer.json"
	[ -f "$ROOT/composer.lock" ] && cp "$ROOT/composer.lock" "$STAGE/composer.lock"
	( cd "$STAGE" && composer install --no-dev --optimize-autoloader --quiet --no-interaction )
	rm -f "$STAGE/composer.json" "$STAGE/composer.lock"
else
	rm -rf "$STAGE/vendor" "$STAGE/composer.json" "$STAGE/composer.lock"
fi

# Drop empty directories: an aborted asset build, or a source tree that never
# had the files, would otherwise ship meaningless empty folders.
find "$STAGE" -type d -empty -delete

echo "  zipping..."
( cd "$DIST/.stage" && zip -rq "$ZIP" "$SLUG" -x '*.DS_Store' )
rm -rf "$DIST/.stage"

SIZE=$(du -h "$ZIP" | cut -f1 | tr -d ' ')
echo
echo "  dist/$(basename "$ZIP")  ($SIZE)"
