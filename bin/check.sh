#!/usr/bin/env bash
# check.sh — run wordpress.org's Plugin Check against the release zip.
#
#   composer check              human-readable table
#   composer check -- --json    machine-readable, for handing to an agent
#
# This answers one question: would this plugin pass wordpress.org review?
# It is slow (boots WordPress in Docker) and meant to be run before a release,
# not on every save. phpcs already covers the sniff-based half continuously.
#
# It checks the BUILT ZIP, not the working directory. That distinction is the
# whole point: the working tree carries tests/, .claude/, AGENTS.md and other
# dev tooling that never ships, and Plugin Check flags every one of them. On a
# freshly scaffolded plugin that is 15 errors against the source tree versus a
# clean run against the zip. Findings against files that don't ship are noise,
# and noise is what stops people running a check at all.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

FORMAT=table
FIELDS=line,column,type,code,message
for arg in "$@"; do
	case "$arg" in
		--json)
			# strict-json, not json: the plain format groups results per file and
			# prints one document per group, so parsing it means splitting
			# concatenated JSON. strict-json emits a single flat array.
			FORMAT=strict-json
			FIELDS=type,code,message,file,line
			;;
		--help|-h)
			sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "check.sh: unknown option: $arg" >&2
			echo "Usage: composer check [-- --json]" >&2
			exit 1
			;;
	esac
done

log() { [ "$FORMAT" = table ] && echo "$@" || true; }

# Themes have no equivalent. Plugin Check resolves everything through
# get_plugins(); there is no theme code path. See the theme-check issue.
if [ ! -f "$ROOT/composer.json" ] || grep -q '"type": "wordpress-theme"' "$ROOT/composer.json"; then
	echo "check.sh: Plugin Check is plugin-only; this project is a theme." >&2
	exit 1
fi

for cmd in docker npx unzip; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "check.sh: missing required tool: $cmd" >&2
		exit 1
	}
done

if ! docker info >/dev/null 2>&1; then
	echo "check.sh: Docker is not running. Start Docker Desktop, then try again." >&2
	exit 1
fi

# Build first, so the zip matches the code as it stands right now. Checking a
# stale zip reports findings that were already fixed.
log "Building the release zip..."
"$ROOT/bin/build.sh" >/dev/null

ZIP=$(ls -t "$ROOT"/dist/*.zip 2>/dev/null | head -1 || true)
[ -n "$ZIP" ] || { echo "check.sh: no zip in dist/ after build." >&2; exit 1; }
ZIP_NAME=$(basename "$ZIP")
log "  $ZIP_NAME"

log "Starting WordPress (first run pulls images and takes a few minutes)..."
# Keep stderr on failure. The common causes — port 8888 already bound by another
# wp-env, Docker out of disk — are all diagnosable from the message, and a bare
# "error code 1" sends people looking in the wrong place.
if ! WP_ENV_OUT=$(npx wp-env start 2>&1); then
	echo "check.sh: wp-env failed to start." >&2
	printf '%s\n' "$WP_ENV_OUT" | tail -20 >&2
	echo >&2
	echo "If a port is already allocated, another project's wp-env is running." >&2
	echo "Stop it with 'npx wp-env stop' in that project, then try again." >&2
	exit 1
fi

# wp-env mounts the project under the container's plugin directory, named for
# the project folder. That name is not necessarily the plugin slug, so derive
# the in-container path from the folder rather than assuming they match.
PROJECT_DIR=$(basename "$ROOT")
WP_ROOT=/var/www/html
IN_CONTAINER_ZIP="$WP_ROOT/wp-content/plugins/$PROJECT_DIR/dist/$ZIP_NAME"

# Installing Plugin Check itself is idempotent; --activate on an active plugin
# is a no-op. Its command only registers inside a booted WordPress, so there is
# no standalone path here.
log "Installing Plugin Check..."
if ! PC_OUT=$(npx wp-env run cli wp plugin install plugin-check --activate 2>&1); then
	echo "check.sh: could not install Plugin Check." >&2
	printf '%s\n' "$PC_OUT" | tail -20 >&2
	exit 1
fi

log "Running checks..."
# --path is required: cd'ing to the unpack directory loses WordPress discovery,
# and without it the command is not registered at all.
OUT=$(npx wp-env run cli sh -c "
	set -e
	rm -rf /tmp/wp-preset-check
	mkdir -p /tmp/wp-preset-check
	unzip -q '$IN_CONTAINER_ZIP' -d /tmp/wp-preset-check
	DIR=\$(find /tmp/wp-preset-check -mindepth 1 -maxdepth 1 -type d | head -1)
	wp --path=$WP_ROOT plugin check \"\$DIR\" --format=$FORMAT --fields=$FIELDS
" 2>/dev/null) || true

# wp-env wraps output in its own status lines. Strip them.
OUT=$(printf '%s\n' "$OUT" | sed '/^ℹ Starting /d; /^✔ Ran /d; /^✖ /d')

if [ "$FORMAT" = strict-json ]; then
	# Plugin Check exits 0 whether or not it found anything — errors included.
	# The exit code only signals whether the tool itself ran. So the caller's
	# pass/fail has to come from the payload, which is why this prints an
	# empty array rather than nothing when the plugin is clean.
	printf '%s\n' "$OUT" | grep -o '^\[.*\]$' | head -1 || echo '[]'
	exit 0
fi

printf '%s\n' "$OUT"

echo
if printf '%s\n' "$OUT" | grep -q 'No errors found'; then
	echo "Clean. This plugin would pass the automated half of wordpress.org review."
	exit 0
fi

cat <<'EOF'
These are findings to assess, not a task list.

Plugin Check flags patterns that are usually wrong but sometimes correct for a
particular plugin. Fixing every line it prints without reading them will make
the code worse. Read each one, decide whether it applies, and use
--ignore-codes for the ones you have judged and rejected.

ERROR blocks a wordpress.org submission. WARNING does not.

To hand these to an agent instead:

    composer check -- --json > findings.json
EOF
