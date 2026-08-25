#!/usr/bin/env bash
# install.sh — install the wp-preset scaffolding command for your AI agent.
#
#   ./skill/install.sh claude    ~/.claude/skills/wp-preset/SKILL.md
#   ./skill/install.sh codex     ~/.codex/prompts/wp-preset.md
#   ./skill/install.sh cursor    ~/.cursor/rules/wp-preset.mdc
#   ./skill/install.sh print     write the generic prompt to stdout
#
# Each target gets the same instructions in the format that tool expects. The
# scaffold path is substituted in, so the installed copy is ready to use.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SRC="$HERE/wp-preset/SKILL.md"

TARGET="${1:-}"
[ -n "$TARGET" ] || { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1; }

[ -f "$SRC" ] || { echo "error: $SRC not found." >&2; exit 1; }

# Body with the scaffold path filled in and frontmatter stripped.
body() {
	# Drop a leading YAML frontmatter block if present (awk: portable on BSD/GNU).
	awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$SRC" \
		| sed "s|\$WP_PRESET|$ROOT|g"
}

# Frontmatter values, reused by the formats that want them.
fm() { sed -n "s/^$1: //p" "$SRC" | head -1; }

# Content arrives as $2, not on stdin: the overwrite prompt needs stdin for the
# answer, and reading both from the same place eats the first line of content.
write() {
	local dst="$1" content="$2"
	if [ -e "$dst" ]; then
		if [ -t 0 ]; then
			printf 'Overwrite %s? [y/N] ' "$dst"
			read -r reply
		else
			# Non-interactive (piped or CI): refuse rather than clobber silently.
			echo "exists, not overwriting: $dst" >&2
			echo "  re-run interactively, or delete it first." >&2
			return 0
		fi
		case "$reply" in [yY]*) ;; *) echo "skipped."; return 0 ;; esac
	fi
	mkdir -p "$(dirname "$dst")"
	printf '%s\n' "$content" > "$dst"
	echo "installed: $dst"
}

case "$TARGET" in
	claude)
		# Native format — copy as-is, only substituting the path.
		write "$HOME/.claude/skills/wp-preset/SKILL.md" \
			"$(sed "s|\$WP_PRESET|$ROOT|g" "$SRC")"
		echo "use: /wp-preset set up the preset for a plugin"
		;;
	codex)
		# Codex reads the file as a plain prompt body; frontmatter would show up
		# as literal text, so drop it.
		write "$HOME/.codex/prompts/wp-preset.md" "$(body)"
		echo "use: /wp-preset"
		;;
	cursor)
		# Cursor rules use .mdc with its own frontmatter keys. agentRequested
		# means the agent pulls it in when the description matches.
		write "$HOME/.cursor/rules/wp-preset.mdc" \
			"$(printf -- '---\ndescription: %s\nalwaysApply: false\n---\n' "$(fm description)"; body)"
		echo "use: ask Cursor to set up the WordPress preset"
		;;
	print)
		body
		;;
	*)
		echo "error: unknown target '$TARGET' (claude|codex|cursor|print)" >&2
		exit 1
		;;
esac
