#!/usr/bin/env bash
# format.sh — project-scoped format-on-save for Claude Code (PostToolUse).
#
# Runs against THIS project only, because it is registered in this project's
# .claude/settings.json. Other projects are unaffected.
#
# PHP  : phpcbf (autofix) -> phpcs (report what's left, exit 2)
# JS/TS: eslint --fix -> prettier --write
# CSS  : prettier --write
#
# Exit 2 with stderr is how Claude Code feeds violations back to the model.

FILE=$(jq -r '.tool_input.file_path // empty')
[ -n "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 0

# Project root = where this hook's settings live (two levels up from hooks/).
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Never touch dependencies, build output, or minified assets.
case "$FILE" in
	*/vendor/*|*/node_modules/*|*/build/*|*/dist/*) exit 0 ;;
	*.min.js|*.min.css|*.asset.php) exit 0 ;;
esac

EXIT_CODE=0

case "$FILE" in
	*.php)
		PHPCBF="$ROOT/vendor/bin/phpcbf"
		PHPCS="$ROOT/vendor/bin/phpcs"
		[ -x "$PHPCBF" ] || exit 0

		( cd "$ROOT" && "$PHPCBF" "$FILE" >/dev/null 2>&1 ) || true

		if [ -x "$PHPCS" ]; then
			if ! ( cd "$ROOT" && "$PHPCS" -q --report=summary "$FILE" >/dev/null 2>&1 ); then
				{
					echo "PHPCS violations remain in $FILE after phpcbf autofix."
					echo "These are NOT auto-fixable — fix them by editing the file:"
					echo
					( cd "$ROOT" && "$PHPCS" --report=full --no-colors "$FILE" 2>/dev/null )
				} >&2
				EXIT_CODE=2
			fi
		fi
		;;

	*.js|*.jsx|*.ts|*.tsx)
		ESLINT="$ROOT/node_modules/.bin/eslint"
		if [ -x "$ESLINT" ]; then
			if ! ( cd "$ROOT" && "$ESLINT" --fix "$FILE" >/dev/null 2>&1 ); then
				( cd "$ROOT" && "$ESLINT" "$FILE" ) >&2
				EXIT_CODE=2
			fi
		fi
		;;
esac

# Prettier last so formatting is the final word.
case "$FILE" in
	*.js|*.jsx|*.ts|*.tsx|*.css|*.scss|*.json|*.md|*.yml|*.yaml)
		PRETTIER="$ROOT/node_modules/.bin/prettier"
		[ -x "$PRETTIER" ] && ( cd "$ROOT" && "$PRETTIER" --write "$FILE" >/dev/null 2>&1 ) || true
		;;
esac

exit $EXIT_CODE
