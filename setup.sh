#!/usr/bin/env bash
# setup.sh — copy this preset into a project and rename placeholders.
#
#   ~/Projects/Tools/"wp-preset"/setup.sh [--theme [--block|--classic]] \
#       [--plugin] [--prefix <base>] <target-dir> <slug> [Prefix]
#
#   slug   : text domain + function prefix base, e.g. acme-widgets
#            -> text domain "acme-widgets", function prefix "acme_widgets"
#   Prefix : class prefix, defaults to StudlyCase of slug (AcmeWidgets)
#
#   --plugin  : (default) creates <slug>.php, type wordpress-plugin,
#               wp-env mounts as a plugin
#   --theme   : creates a theme, type wordpress-theme, wp-env mounts as a theme.
#               Asks which kind unless --block or --classic says.
#   --block   : block theme — theme.json, templates/, parts/
#   --classic : classic theme — index.php, header.php, footer.php
#   --prefix  : function/constant prefix base, independent of the slug.
#               A wordpress.org slug has to stay long, but a family of sibling
#               plugins usually wants a short shared prefix:
#                 --prefix acme_otic  ->  acme_otic_*, ACME_OTIC_*
#               The text domain always stays the slug; WordPress requires it.
#
# Copies config only — never overwrites an existing file. Does not install.
set -euo pipefail

PRESET_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

USAGE='usage: setup.sh [--theme [--block|--classic]] [--plugin] [--prefix <base>] <target-dir> <slug> [Prefix]'

KIND=plugin
THEME_KIND=""
PREFIX_BASE=""
# A loop rather than a single case: --prefix takes a value, and flags should not
# have to come in a fixed order.
while [ $# -gt 0 ]; do
	case "$1" in
		--theme)  KIND=theme;  shift ;;
		--plugin) KIND=plugin; shift ;;
		# Back-compat: --no-main was the old spelling of --theme's file behaviour.
		--no-main) KIND=theme; shift ;;
		--block)   KIND=theme; THEME_KIND=block;   shift ;;
		--classic) KIND=theme; THEME_KIND=classic; shift ;;
		--prefix)
			[ -n "${2:-}" ] || { echo "--prefix needs a value, e.g. --prefix acme_otic" >&2; exit 1; }
			PREFIX_BASE="$2"; shift 2 ;;
		--prefix=*)
			PREFIX_BASE="${1#*=}"
			[ -n "$PREFIX_BASE" ] || { echo "--prefix needs a value, e.g. --prefix acme_otic" >&2; exit 1; }
			shift ;;
		--) shift; break ;;
		-*) echo "unknown option: $1" >&2; echo "$USAGE" >&2; exit 1 ;;
		*) break ;;
	esac
done

# The loop stops at the first positional, so a flag placed after one would be
# read as a positional value — `setup.sh ./p slug --prefix x` would name every
# generated class "--prefix". Reject that instead of producing invalid PHP.
for arg in "$@"; do
	case "$arg" in
		-*) echo "options must come before <target-dir>: $arg" >&2
		    echo "$USAGE" >&2; exit 1 ;;
	esac
done

TARGET="${1:?$USAGE}"
SLUG="${2:?$USAGE}"

case "$SLUG" in
	[a-z]*) ;;
	*) echo "slug must be lowercase-kebab, e.g. acme-widgets" >&2; exit 1 ;;
esac

# The function/constant prefix defaults to the slug, but a slug has to stay long
# for the text domain and the wordpress.org listing. --prefix decouples them, so
# a family of sibling plugins can share a short brand prefix.
if [ -n "$PREFIX_BASE" ]; then
	# Must be a valid PHP identifier: the constant form is uppercased from it.
	case "$PREFIX_BASE" in
		[a-z_]*[!a-z0-9_]*|*[!a-z0-9_]*)
			echo "--prefix must be lowercase snake_case, e.g. acme_otic" >&2; exit 1 ;;
		[0-9]*)
			echo "--prefix cannot start with a digit" >&2; exit 1 ;;
	esac
	UNDER="$PREFIX_BASE"
else
	UNDER=${SLUG//-/_}
fi

# A theme has to be one kind or the other — WordPress rejects a theme carrying
# neither templates/index.html nor index.php. Ask rather than pick, since the
# choice decides how the whole theme is built and is awkward to change later.
if [ "$KIND" = "theme" ] && [ -z "$THEME_KIND" ]; then
	if [ -t 0 ] && [ -t 1 ]; then
		echo "Which kind of theme?"
		echo "  1) block   — theme.json, templates/, Site Editor (WordPress 5.9+)"
		echo "  2) classic — index.php, header.php, footer.php, PHP templates"
		echo
		while true; do
			printf 'Choose [1/2]: '
			read -r reply || { echo; echo "no answer; pass --block or --classic" >&2; exit 1; }
			case "$reply" in
				1|block|b)   THEME_KIND=block;   break ;;
				2|classic|c) THEME_KIND=classic; break ;;
				*) echo "  enter 1 or 2" ;;
			esac
		done
		echo
	else
		# Non-interactive: never guess silently. A wrong kind is a wide rewrite.
		echo "--theme needs --block or --classic when stdin is not a terminal." >&2
		echo "  --block   theme.json, templates/, parts/  (Site Editor)" >&2
		echo "  --classic index.php, header.php, footer.php" >&2
		exit 1
	fi
fi

if [ -n "${3:-}" ]; then
	STUDLY="$3"
else
	STUDLY=$(printf '%s' "$SLUG" | awk -F- '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1)) substr($i,2)}')
fi

UPPER=$(printf '%s' "$UNDER" | tr '[:lower:]' '[:upper:]')
# Human-readable name for plugin headers: acme-widgets -> Acme Widgets
TITLE=$(printf '%s' "$SLUG" | awk -F- '{for(i=1;i<=NF;i++){printf "%s%s", toupper(substr($i,1,1)) substr($i,2), (i<NF?" ":"")}}')

mkdir -p "$TARGET"
echo "wp-preset -> $TARGET"
echo "  text domain / slug : $SLUG"
echo "  function prefix    : ${UNDER}_"
echo "  constant prefix    : ${UPPER}_"
echo "  class prefix       : $STUDLY"
[ "$KIND" = "theme" ] && echo "  theme kind         : $THEME_KIND"
echo

# Files this run actually created. The kind-specific rewrites below consult it:
# a file we skipped belongs to the user, and editing it would break the
# no-overwrite contract just as surely as replacing it would.
COPIED=()

copy() {
	local rel="$1"
	local src="$PRESET_ROOT/$rel"
	local dst="$TARGET/$rel"
	[ -e "$src" ] || return 0
	if [ -e "$dst" ]; then
		echo "  skip (exists): $rel"
		return 0
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	COPIED+=("$rel")
	echo "  copied: $rel"
}

# True when this run created the file, false when it was already there.
was_copied() {
	local needle="$1"
	local f
	for f in ${COPIED+"${COPIED[@]}"}; do
		[ "$f" = "$needle" ] && return 0
	done
	return 1
}

# In-place sed that works on both GNU and BSD/macOS. `-i` takes an *attached*
# suffix, never a separate argument: BSD reads `-i ''` as an empty suffix, while
# GNU reads it as `-i` with no suffix plus `''` as a filename, then fails on the
# unreadable file. `-i.bak` is the one spelling both accept, so write a backup
# and delete it.
sed_inplace() {
	local file="$1"; shift
	sed -i.bak "$@" "$file" && rm -f "$file.bak"
}

# Copy a preset file to a different name in the target.
copy_as() {
	local src="$PRESET_ROOT/$1"
	local dst="$TARGET/$2"
	[ -e "$src" ] || return 0
	if [ -e "$dst" ]; then
		echo "  skip (exists): $2"
		return 0
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	COPIED+=("$2")
	echo "  copied: $2"
}

# Entry points differ by kind: a plugin has <slug>.php; a theme has
# style.css + functions.php.
if [ "$KIND" = "theme" ]; then
	copy_as "theme/style.css" "style.css"
	copy_as "theme/functions.php" "functions.php"
	copy_as "theme/AGENTS.md" "AGENTS.md"
	copy_as "theme/CLAUDE.md" "CLAUDE.md"
	copy_as "bin/build.sh" "bin/build.sh"
	chmod +x "$TARGET/bin/build.sh" 2>/dev/null || true

	# WordPress needs one of these to recognise the directory as a theme at all.
	if [ "$THEME_KIND" = "block" ]; then
		copy_as "theme/block/theme.json" "theme.json"
		copy_as "theme/block/templates/index.html" "templates/index.html"
		copy_as "theme/block/parts/header.html" "parts/header.html"
		copy_as "theme/block/parts/footer.html" "parts/footer.html"
	else
		copy_as "theme/classic/index.php" "index.php"
		copy_as "theme/classic/header.php" "header.php"
		copy_as "theme/classic/footer.php" "footer.php"
		# Theme supports a block theme gets from theme.json instead. Appended
		# rather than copied, so both kinds share one functions.php template.
		if was_copied "functions.php"; then
			cat "$PRESET_ROOT/theme/classic/functions-classic.php" >> "$TARGET/functions.php"
			echo "  extended: functions.php (classic theme supports)"
		fi
	fi
else
	copy_as "wp-project.php" "$SLUG.php"
	# wordpress.org reads readme.txt, and Plugin Check fails a plugin that
	# has none. Plugin-only: themes have their own conventions (see #21).
	copy_as "plugin/readme.txt" "readme.txt"
	copy_as "plugin/AGENTS.md" "AGENTS.md"
	copy_as "plugin/CLAUDE.md" "CLAUDE.md"
	copy_as "bin/build.sh" "bin/build.sh"
	# Plugin Check is plugin-only, so themes do not get this. See #21.
	copy_as "bin/check.sh" "bin/check.sh"
	chmod +x "$TARGET/bin/build.sh" "$TARGET/bin/check.sh" 2>/dev/null || true
fi

# NOTE: README.md and skill/ are repo documentation, not project files — never
# add them here. Everything in this list is copied into the target project.
for f in composer.json package.json phpcs.xml.dist phpstan.neon.dist \
         phpunit.xml.dist phpunit-integration.xml.dist \
         tests/bootstrap-unit.php tests/bootstrap-integration.php \
         tests/unit/ExampleTest.php tests/unit/WpMockExampleTest.php \
         tests/unit/AutoloadTest.php \
         tests/integration/ExampleTest.php \
         includes/Example.php \
         .prettierrc.js .prettierignore eslint.config.mjs .editorconfig .gitignore \
         .wp-env.json .claude/settings.json .claude/hooks/format.sh; do
	copy "$f"
done
chmod +x "$TARGET/.claude/hooks/format.sh" 2>/dev/null || true

# Rename placeholders in the copied files only.
echo
echo "Renaming placeholders..."
RENAME_FILES=( composer.json package.json phpcs.xml.dist CLAUDE.md AGENTS.md
               tests/bootstrap-unit.php tests/bootstrap-integration.php
               tests/unit/ExampleTest.php tests/unit/WpMockExampleTest.php
               tests/unit/AutoloadTest.php
               tests/integration/ExampleTest.php
               includes/Example.php )
if [ "$KIND" = "theme" ]; then
	RENAME_FILES+=( style.css functions.php )
	if [ "$THEME_KIND" = "block" ]; then
		RENAME_FILES+=( theme.json )
	else
		RENAME_FILES+=( index.php header.php footer.php )
	fi
else
	RENAME_FILES+=( "$SLUG.php" readme.txt )
fi

for f in "${RENAME_FILES[@]}"; do
	[ -f "$TARGET/$f" ] || continue
	# Rename only what this run created. A file we skipped is the user's, and
	# rewriting its contents violates the no-overwrite contract as surely as
	# replacing it would — the placeholders are strings a real project may use.
	# copy() already reported the skip; don't say it twice.
	was_copied "$f" || continue
	# Order matters: the uppercase constant form must be rewritten before the
	# lowercase rules, and WpProject before either would corrupt it.
	sed_inplace "$TARGET/$f" \
		-e "s/WP Project/$TITLE/g" \
		-e "s/WP_PROJECT_/${UPPER}_/g" \
		-e "s/WpProject/$STUDLY/g" \
		-e "s/wp-project/$SLUG/g" \
		-e "s/wp_project/${UNDER}/g"
	echo "  updated: $f"
done

# "Tested up to" is the one header that goes stale on its own. wordpress.org
# treats a value behind the current release as an error and drops the plugin out
# of search results, so a hardcoded template value fails on a schedule set by
# WordPress rather than by anything in the project. Stamp the current version at
# scaffold time so a new plugin at least starts correct; `composer check` reports
# it once it drifts again.
if [ "$KIND" = plugin ] && was_copied "readme.txt"; then
	WP_CURRENT=""
	if command -v curl >/dev/null 2>&1 && command -v php >/dev/null 2>&1; then
		WP_CURRENT=$(curl -sS --max-time 10 \
			"https://api.wordpress.org/core/version-check/1.7/" 2>/dev/null \
			| php -r '
				$j = json_decode(stream_get_contents(STDIN), true);
				$v = $j["offers"][0]["current"] ?? "";
				// Major version only: a three-part value is itself an error.
				if (preg_match("/^(\d+\.\d+)/", $v, $m)) {
					echo $m[1];
				}
			' 2>/dev/null || true)
	fi
	if [ -n "$WP_CURRENT" ]; then
		sed_inplace "$TARGET/readme.txt" "s/^Tested up to:.*/Tested up to:      $WP_CURRENT/"
		echo "  readme.txt    -> Tested up to: $WP_CURRENT"
	else
		# Offline, or the API changed shape. The template value still parses, so
		# the scaffold works; it just starts out flagged.
		echo "  note: could not reach wordpress.org; check 'Tested up to' in readme.txt" >&2
	fi
fi

# With --prefix the function prefix and the slug diverge, but option, transient
# and meta keys stay slug-derived — wordpress.org expects those to match the
# directory. PrefixAllGlobals checks those too, so it needs both prefixes or it
# flags every slug-named option.
# was_copied gates this for the same reason it gates the rewrites above: an
# existing phpcs.xml.dist carries the user's own prefixes and is not ours to edit.
SLUG_UNDER=${SLUG//-/_}
if [ -n "$PREFIX_BASE" ] && [ "$UNDER" != "$SLUG_UNDER" ] && was_copied "phpcs.xml.dist"; then
	php -r '
		$f = $argv[1];
		$slug_prefix = $argv[2];
		$s = file_get_contents($f);
		$needle = "\t\t\t\t<element value=\"" . $slug_prefix . "\"/>\n";
		if (strpos($s, $needle) !== false) {
			exit(0);
		}
		// Add it alongside the short prefix inside the same prefixes array.
		$s = preg_replace(
			"#(<property name=\"prefixes\" type=\"array\">\n)#",
			"$1" . $needle,
			$s,
			1
		);
		file_put_contents($f, $s);
	' "$TARGET/phpcs.xml.dist" "$SLUG_UNDER"
	echo "  phpcs.xml.dist -> kept \"$SLUG_UNDER\" for option/transient keys"
fi

# Kind-specific config. Doing this here rather than leaving it to the caller:
# a theme mounted as a plugin never shows under Appearance > Themes.
if [ "$KIND" = "theme" ]; then
	echo
	echo "Configuring as a theme..."
	# Only rewrite files this run created. A pre-existing .wp-env.json is the
	# user's — it may mount sibling projects or set options we know nothing
	# about, and rewriting it would break the no-overwrite contract as surely as
	# replacing it would.
	if was_copied ".wp-env.json"; then
		# Rename the mount key via a JSON parser, not sed. A sed pattern has to
		# match the file's exact whitespace, and a non-matching s/// is silent —
		# the earlier pattern expected [ "." ] while the file held ["."], so
		# every scaffolded theme mounted as a plugin while this line claimed
		# success.
		php -r '
			$f = $argv[1];
			$j = json_decode(file_get_contents($f), true);
			// Rebuild in order so "themes" lands where "plugins" was; PHP would
			// otherwise append it after an unset.
			$new = [];
			foreach ($j as $k => $v) {
				$new[$k === "plugins" ? "themes" : $k] = $v;
			}
			$out = json_encode($new, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
			// Match the tab indentation used everywhere else in the preset.
			$out = preg_replace_callback("/^( +)/m", function ($m) {
				return str_repeat("\t", intdiv(strlen($m[1]), 4));
			}, $out);
			// Keep the single-element mount array inline, as Prettier does.
			$out = preg_replace("/\[\n\t+\"\.\"\n\t+\]/", "[\".\"]", $out);
			file_put_contents($f, $out . "\n");
		' "$TARGET/.wp-env.json"
		echo "  .wp-env.json  -> \"themes\": [ \".\" ]"
	else
		echo "  skip (exists): .wp-env.json — set \"themes\": [ \".\" ] yourself"
	fi

	if was_copied "composer.json"; then
		sed_inplace "$TARGET/composer.json" 's/"type": "wordpress-plugin"/"type": "wordpress-theme"/'
		echo "  composer.json -> \"type\": \"wordpress-theme\""
		# Plugin Check has no theme code path, so bin/check.sh is not copied for
		# a theme. Leaving the script entry behind would advertise a command
		# whose file does not exist. See #21.
		php -r '
			$f = $argv[1];
			$j = json_decode(file_get_contents($f), true);
			unset($j["scripts"]["check"]);
			$out = json_encode($j, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
			$out = preg_replace_callback("/^( +)/m", function ($m) {
				return str_repeat("\t", intdiv(strlen($m[1]), 4));
			}, $out);
			file_put_contents($f, $out . "\n");
		' "$TARGET/composer.json"
		echo "  composer.json -> removed \"check\" (plugin-only)"
	else
		echo "  skip (exists): composer.json — set \"type\": \"wordpress-theme\" yourself"
	fi
fi

cat <<EOF

Next:
  cd "$TARGET"
  composer install
  npm install

Then verify:
  composer phpcs
  composer phpstan
  npm run lint:js

Format-on-save is active via .claude/hooks/format.sh once deps are installed.
It stays silent until then, so install before relying on it.
EOF
