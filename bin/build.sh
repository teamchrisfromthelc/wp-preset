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

# Check tools up front. Both are absent from a minimal Debian/Ubuntu install,
# and under `set -e` a missing one aborts mid-build with a bare "command not
# found" naming no remedy — after the staging directory already exists.
MISSING=()
for cmd in rsync zip; do
	command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done
if [ ${#MISSING[@]} -gt 0 ]; then
	echo "build.sh: missing required tool(s): ${MISSING[*]}" >&2
	echo "  Debian/Ubuntu : sudo apt install ${MISSING[*]}" >&2
	echo "  macOS         : brew install ${MISSING[*]}" >&2
	exit 1
fi

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

VERSION=$(grep -m1 -E '^[[:space:]]*\*?[[:space:]]*Version:' "$MAIN" | sed -E 's/.*Version:[[:space:]]*//' | tr -d '[:space:]')

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
		echo "Set every copy to the same value, then build again."
	} >&2
	exit 1
fi

# readme.txt is a third place the version lives, and it is the one wordpress.org
# actually reads to decide which release to serve. A stale Stable tag means the
# directory keeps serving the old version no matter what was uploaded, so this
# fails for the same reason the constant check does. Plugins only: a theme has
# no readme.txt in this scaffold. Absent readme.txt is fine — not every plugin
# is destined for wordpress.org.
if [ "$KIND" = plugin ] && [ -f "$ROOT/readme.txt" ]; then
	STABLE_TAG=$(grep -m1 -E '^[[:space:]]*Stable tag:' "$ROOT/readme.txt" \
		| sed -E 's/.*Stable tag:[[:space:]]*//' | tr -d '[:space:]' || true)
	# "trunk" is not accepted here. It used to be idiomatic, but Plugin Check
	# raises it as an error now, so a build that allowed it would produce a zip
	# that fails review.
	if [ -n "$STABLE_TAG" ] && [ "$STABLE_TAG" != "$VERSION" ]; then
		{
			echo "error: version mismatch."
			echo "  $(basename "$MAIN")"
			echo "    Version: header   $VERSION"
			echo "  readme.txt"
			echo "    Stable tag        $STABLE_TAG"
			echo "Set every copy to the same value, then build again."
		} >&2
		exit 1
	fi
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
HAS_AUTOLOAD=0
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

	# A project mapping its own classes needs an autoloader in the zip even with
	# no runtime dependencies — otherwise the entry point's require of
	# vendor/autoload.php finds nothing and every class in includes/ is missing
	# at runtime, while working fine in development.
	HAS_AUTOLOAD=$(php -r '
		$j = json_decode(file_get_contents($argv[1]), true);
		echo (is_array($j) && ! empty($j["autoload"])) ? "1" : "0";
	' "$ROOT/composer.json" 2>/dev/null || echo 0)
fi

if [ "$HAS_RUNTIME_DEPS" = "1" ]; then
	echo "  installing production dependencies..."
	cp "$ROOT/composer.json" "$STAGE/composer.json"
	[ -f "$ROOT/composer.lock" ] && cp "$ROOT/composer.lock" "$STAGE/composer.lock"
	( cd "$STAGE" && composer install --no-dev --optimize-autoloader --quiet --no-interaction )
	# composer.json stays. A vendor/ directory with no composer.json beside it is
	# what wordpress.org flags as missing_composer_json_file — reviewers cannot
	# tell what the bundled code is. composer.lock does not ship: it pins dev
	# versions too and says nothing useful about the release.
	rm -f "$STAGE/composer.lock"
elif [ "$HAS_AUTOLOAD" = "1" ]; then
	echo "  generating autoloader..."
	rm -rf "$STAGE/vendor"
	cp "$ROOT/composer.json" "$STAGE/composer.json"
	# dump-autoload rather than install: there is nothing to fetch, and this
	# writes only the project's own class map.
	( cd "$STAGE" && composer dump-autoload --no-dev --optimize --quiet --no-interaction )
	rm -f "$STAGE/composer.lock"
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
