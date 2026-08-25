#!/usr/bin/env bash
# setup.sh — copy this preset into a project and rename placeholders.
#
#   ~/Projects/Tools/"wp-preset"/setup.sh [--theme|--plugin] <target-dir> <slug> [Prefix]
#
#   slug   : text domain + function prefix base, e.g. acme-widgets
#            -> text domain "acme-widgets", function prefix "acme_widgets"
#   Prefix : class prefix, defaults to StudlyCase of slug (AcmeWidgets)
#
#   --plugin  : (default) creates <slug>.php, type wordpress-plugin,
#               wp-env mounts as a plugin
#   --theme   : creates style.css + functions.php, type wordpress-theme,
#               wp-env mounts as a theme
#
# Copies config only — never overwrites an existing file. Does not install.
set -euo pipefail

PRESET_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

KIND=plugin
case "${1:-}" in
	--theme)  KIND=theme;  shift ;;
	--plugin) KIND=plugin; shift ;;
	# Back-compat: --no-main was the old spelling of --theme's file behaviour.
	--no-main) KIND=theme; shift ;;
esac

USAGE='usage: setup.sh [--theme|--plugin] <target-dir> <slug> [Prefix]'
TARGET="${1:?$USAGE}"
SLUG="${2:?$USAGE}"

case "$SLUG" in
	[a-z]*) ;;
	*) echo "slug must be lowercase-kebab, e.g. acme-widgets" >&2; exit 1 ;;
esac

UNDER=${SLUG//-/_}
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
echo "  class prefix       : $STUDLY"
echo

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
	echo "  copied: $rel"
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
	echo "  copied: $2"
}

# Entry points differ by kind: a plugin has <slug>.php; a theme has
# style.css + functions.php.
if [ "$KIND" = "theme" ]; then
	copy_as "theme/style.css" "style.css"
	copy_as "theme/functions.php" "functions.php"
	copy_as "theme/AGENTS.md" "AGENTS.md"
	copy_as "theme/CLAUDE.md" "CLAUDE.md"
else
	copy_as "wp-project.php" "$SLUG.php"
	copy_as "plugin/AGENTS.md" "AGENTS.md"
	copy_as "plugin/CLAUDE.md" "CLAUDE.md"
	copy_as "bin/build-plugin.sh" "bin/build-plugin.sh"
	chmod +x "$TARGET/bin/build-plugin.sh" 2>/dev/null || true
fi

# NOTE: README.md and skill/ are repo documentation, not project files — never
# add them here. Everything in this list is copied into the target project.
for f in composer.json package.json phpcs.xml.dist phpstan.neon.dist \
         phpunit.xml.dist phpunit-integration.xml.dist \
         tests/bootstrap-unit.php tests/bootstrap-integration.php \
         tests/unit/ExampleTest.php tests/unit/WpMockExampleTest.php \
         tests/integration/ExampleTest.php \
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
               tests/integration/ExampleTest.php )
if [ "$KIND" = "theme" ]; then
	RENAME_FILES+=( style.css functions.php )
else
	RENAME_FILES+=( "$SLUG.php" )
fi

for f in "${RENAME_FILES[@]}"; do
	[ -f "$TARGET/$f" ] || continue
	# macOS/BSD sed needs the empty -i argument.
	# Order matters: the uppercase constant form must be rewritten before the
	# lowercase rules, and WpProject before either would corrupt it.
	sed -i '' \
		-e "s/WP Project/$TITLE/g" \
		-e "s/WP_PROJECT_/${UPPER}_/g" \
		-e "s/WpProject/$STUDLY/g" \
		-e "s/wp-project/$SLUG/g" \
		-e "s/wp_project/${UNDER}/g" \
		"$TARGET/$f"
	echo "  updated: $f"
done

# Kind-specific config. Doing this here rather than leaving it to the caller:
# a theme mounted as a plugin never shows under Appearance > Themes.
if [ "$KIND" = "theme" ]; then
	echo
	echo "Configuring as a theme..."
	sed -i '' 's/"plugins": \[ "\." \]/"themes": [ "." ]/' "$TARGET/.wp-env.json"
	echo "  .wp-env.json  -> \"themes\": [ \".\" ]"
	sed -i '' 's/"type": "wordpress-plugin"/"type": "wordpress-theme"/' "$TARGET/composer.json"
	echo "  composer.json -> \"type\": \"wordpress-theme\""
	# bin/build-plugin.sh packages plugins only; drop the script that calls it.
	# Edited via PHP rather than sed — removing a JSON key needs a real parser
	# to avoid leaving a trailing comma.
	php -r '
		$f = $argv[1];
		$j = json_decode(file_get_contents($f), true);
		unset($j["scripts"]["build"]);
		$out = json_encode($j, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
		// Match the tab indentation used everywhere else in the preset.
		$out = preg_replace_callback("/^( +)/m", function ($m) {
			return str_repeat("\t", intdiv(strlen($m[1]), 4));
		}, $out);
		file_put_contents($f, $out . "\n");
	' "$TARGET/composer.json"
	echo "  composer.json -> removed \"build\" script"
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
