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
# Options passed straight through to `wp plugin check`. --ignore-codes is the
# one the docs tell people to reach for once they have judged a finding, so
# rejecting it made the documented workflow impossible.
PASSTHROUGH=()
for arg in "$@"; do
	case "$arg" in
		--json)
			# strict-json, not json: the plain format groups results per file and
			# prints one document per group, so parsing it means splitting
			# concatenated JSON. strict-json emits a single flat array.
			FORMAT=strict-json
			FIELDS=type,code,message,file,line
			;;
		--ignore-codes=*|--ignore-warnings|--ignore-errors|--include-experimental|\
		--checks=*|--exclude-checks=*|--categories=*|--severity=*|\
		--exclude-directories=*|--exclude-files=*)
			PASSTHROUGH+=("$arg")
			;;
		--format=*|--fields=*)
			# These decide how this script parses the result. Letting them
			# through would break --json silently.
			echo "check.sh: $arg is set by this script; use --json instead." >&2
			exit 1
			;;
		--help|-h)
			sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
			echo
			echo "Options are passed through to 'wp plugin check', e.g."
			echo "  composer check -- --ignore-codes=missing_readme_header"
			exit 0
			;;
		*)
			echo "check.sh: unknown option: $arg" >&2
			echo "Usage: composer check [-- --json] [-- <wp plugin check options>]" >&2
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
	case "$WP_ENV_OUT" in
		*"port is already allocated"*)
			echo "Another project's wp-env holds that port. Run 'npx wp-env stop'" >&2
			echo "in that project, then try again." >&2
			;;
		*"unexpected EOF"*)
			# wp-env builds its own shell command from the project path and does
			# not quote it, so a quote in a directory name breaks wp-env itself
			# before anything here runs. Nothing this script can work around.
			echo "This looks like wp-env's own quoting bug: it builds a shell" >&2
			echo "command from the project path without quoting it, so a quote" >&2
			echo "character in a directory name breaks it." >&2
			echo "Path: $ROOT" >&2
			echo "Rename the directory to avoid quote characters." >&2
			;;
	esac
	exit 1
fi

WP_ROOT=/var/www/html

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
# wp-env mounts the project under the container's plugin directory, but the
# mount is named for the project folder rather than the slug and the two often
# differ. Rather than reconstruct that path on the host — which breaks on a
# folder name containing a quote — find the zip by name inside the container.
# Only the zip's basename crosses the boundary, and build.sh derives that from
# the plugin's own headers, so it holds no user-controlled path.
#
# Forwarded options are passed as positional arguments after the script — the
# "sh" is $0 — and read back through "$@". Interpolating them into the script
# text instead makes any value with a semicolon a command that runs inside the
# container.
OUT=$(npx wp-env run cli sh -c "
	set -e
	ZIP=\$(find $WP_ROOT/wp-content/plugins -maxdepth 3 -type f \
		-name '$ZIP_NAME' -path '*/dist/*' | head -1)
	if [ -z \"\$ZIP\" ]; then
		echo 'could not find $ZIP_NAME inside the container' >&2
		exit 1
	fi
	rm -rf /tmp/wp-preset-check
	mkdir -p /tmp/wp-preset-check
	unzip -q \"\$ZIP\" -d /tmp/wp-preset-check
	DIR=\$(find /tmp/wp-preset-check -mindepth 1 -maxdepth 1 -type d | head -1)
	wp --path=$WP_ROOT plugin check \"\$DIR\" --format=$FORMAT --fields=$FIELDS \"\$@\"
" sh ${PASSTHROUGH+"${PASSTHROUGH[@]}"}) && RUN_STATUS=0 || RUN_STATUS=$?

# A failure here means the check never ran: the zip was not found, the unzip
# failed, or wp-cli errored. That is not a clean plugin, and reporting it as one
# is the worst thing this script could do — in JSON mode an empty payload is
# indistinguishable from a pass. Plugin Check's own exit code is always 0, so
# a non-zero status can only mean the infrastructure broke.
if [ "$RUN_STATUS" -ne 0 ]; then
	echo "check.sh: Plugin Check did not run (exit $RUN_STATUS)." >&2
	# wp-env echoes the whole script it is about to run before any error, so a
	# plain tail shows that echo rather than the cause. Keep the lines that
	# actually diagnose it.
	printf '%s\n' "$OUT" \
		| grep -vE "^(ℹ Starting|✔ Ran)" \
		| grep -iE "error|fatal|failed|not found|cannot|no such|could not" \
		| tail -10 >&2 || printf '%s\n' "$OUT" | tail -10 >&2
	exit "$RUN_STATUS"
fi

# wp-env wraps output in its own status lines. Strip them.
OUT=$(printf '%s\n' "$OUT" | sed '/^ℹ Starting /d; /^✔ Ran /d; /^✖ /d')

# Belt and braces: a zero status with no recognisable output means something
# changed upstream. Fail rather than print an empty array.
if [ -z "${OUT//[[:space:]]/}" ]; then
	echo "check.sh: Plugin Check produced no output. It may have failed silently." >&2
	exit 1
fi

if [ "$FORMAT" = strict-json ]; then
	# Plugin Check exits 0 whether or not it found anything — errors included.
	# The exit code only signals whether the tool itself ran, so a caller's
	# pass/fail has to come from the payload: [] means clean.
	#
	# Which is exactly why an unparseable payload must not become []. Anything
	# that is not a valid array here means the run did something unexpected, and
	# inventing an empty one would report that as a pass.
	PAYLOAD=$(printf '%s\n' "$OUT" | grep -o '^\[.*\]$' | head -1 || true)
	if [ -z "$PAYLOAD" ]; then
		# A clean plugin prints "Success: Checks complete. No errors found."
		# rather than an empty array, so that specific line is the one case
		# where no JSON is still a valid answer. Anything else means the run
		# did something unexpected, and inventing [] would report it as a pass.
		if printf '%s\n' "$OUT" | grep -q 'Checks complete\. No errors found'; then
			echo '[]'
			exit 0
		fi
		echo "check.sh: no JSON array in Plugin Check's output." >&2
		printf '%s\n' "$OUT" | tail -10 >&2
		exit 1
	fi
	# php rather than python3: this is a WordPress project, so php is already a
	# hard requirement and the rest of the scaffold parses JSON with it.
	if ! printf '%s' "$PAYLOAD" | php -r 'exit(is_array(json_decode(stream_get_contents(STDIN), true)) ? 0 : 1);' 2>/dev/null; then
		echo "check.sh: Plugin Check's output is not a JSON array." >&2
		printf '%s\n' "$PAYLOAD" | head -5 >&2
		exit 1
	fi
	printf '%s\n' "$PAYLOAD"
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
