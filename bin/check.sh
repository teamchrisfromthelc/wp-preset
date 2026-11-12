#!/usr/bin/env bash
# check.sh — run wordpress.org's own review tool against the release zip:
# Plugin Check for a plugin, Theme Check for a theme.
#
#   composer check              human-readable table
#   composer check -- --json    machine-readable, for handing to an agent
#
# This answers one question: would this project pass wordpress.org review?
# It is slow (boots WordPress in Docker) and meant to be run before a release,
# not on every save. phpcs already covers the sniff-based half continuously.
#
# The WordPress it boots is its own, not the one `npm run env:start` gives you:
# a disposable wp-env on free ports, removed when the check ends, fails or is
# interrupted. Your dev site is never stopped, reset or given Plugin Check.
# bin/wp-env-disposable.sh explains how.
#
# It checks the BUILT ZIP, not the working directory. That distinction is the
# whole point: the working tree carries tests/, .claude/, AGENTS.md and other
# dev tooling that never ships, and both tools flag every one of them. On a
# freshly scaffolded plugin that is 15 errors against the source tree versus a
# clean run against the zip. Findings against files that don't ship are noise,
# and noise is what stops people running a check at all.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

# The same signal build.sh uses: a theme declares "Theme Name:" in style.css.
# composer.json's type is not trusted for this, because setup.sh never rewrites
# a composer.json that already existed.
KIND=plugin
grep -qs 'Theme Name:' "$ROOT/style.css" && KIND=theme

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
			if [ "$KIND" = theme ]; then
				# Theme Check has no options beyond the output format. Accepting
				# these and dropping them would report findings the caller asked
				# to exclude.
				echo "check.sh: $arg is a Plugin Check option; Theme Check takes none." >&2
				exit 1
			fi
			PASSTHROUGH+=("$arg")
			;;
		--format=*|--fields=*)
			# These decide how this script parses the result. Letting them
			# through would break --json silently.
			echo "check.sh: $arg is set by this script; use --json instead." >&2
			exit 1
			;;
		--help|-h)
			awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
			echo
			if [ "$KIND" = plugin ]; then
				echo "Options are passed through to 'wp plugin check', e.g."
				echo "  composer check -- --ignore-codes=missing_readme_header"
			else
				echo "Theme Check takes no options. Exit 1 means a REQUIRED finding."
			fi
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

if [ "$KIND" = plugin ]; then
	TOOL="Plugin Check"
	TOOL_SLUG=plugin-check
	CONTENT_DIR=plugins
else
	TOOL="Theme Check"
	TOOL_SLUG=theme-check
	CONTENT_DIR=themes
fi

for cmd in docker node npx php unzip; do
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

# Registers the cleanup trap before anything starts. --no-tests: the check needs
# one WordPress, not the second site wp-env keeps for PHPUnit.
# shellcheck source=bin/wp-env-disposable.sh
. "$ROOT/bin/wp-env-disposable.sh"
wpenv_disposable_init "$ROOT" --no-tests

log "Starting a disposable WordPress (first run pulls images and takes a few minutes)..."
# Keep stderr on failure. The common causes — Docker out of disk, a port taken —
# are all diagnosable from the message, and a bare "error code 1" sends people
# looking in the wrong place.
if ! WP_ENV_OUT=$(wpenv_disposable start 2>&1); then
	echo "check.sh: wp-env failed to start." >&2
	printf '%s\n' "$WP_ENV_OUT" | tail -20 >&2
	echo >&2
	case "$WP_ENV_OUT" in
		*"port is already allocated"*)
			# The ports were free when picked, so something claimed one in the
			# seconds before Docker bound it. A rerun picks new ones.
			echo "Another process took a port this check had picked. Run it again." >&2
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

# Into the disposable site, which starts without it every time. Both tools
# register their WP-CLI command only inside a booted WordPress, so there is no
# standalone path here.
log "Installing $TOOL..."
if ! PC_OUT=$(wpenv_disposable run cli wp plugin install "$TOOL_SLUG" --activate 2>&1); then
	echo "check.sh: could not install $TOOL." >&2
	printf '%s\n' "$PC_OUT" | tail -20 >&2
	exit 1
fi

# Theme Check takes an installed theme's slug, not a path, so the unpacked zip
# has to become a theme WordPress can find. Installing it with `wp theme install`
# would do that, but when the project folder is named for the slug — the usual
# case — the install target is the wp-env mount, and --force would overwrite the
# working tree. Registering the unpack directory as an extra theme root instead
# leaves the site untouched; a registered root wins over wp-content/themes on a
# slug collision, and the resolved path is asserted before the run regardless.
#
# The unpack path matters twice over. The copyright check only reads files under
# "<slug>/", and the screenshot size checks only run on a path containing
# "themes/". Unpack anywhere else and both pass without looking.
#
# theme_roots is a site transient. Registering a root changes what it would
# hold, so it is cleared before and after the run; otherwise the site would
# keep resolving the slug to a /tmp directory that is about to disappear. The
# site is thrown away afterwards anyway, but a cached root would also outlive
# a second check run against the same environment.
#
# Arguments arrive positionally, never interpolated into the script text.
# shellcheck disable=SC2016 # Expanded by the container's shell, not this one.
THEME_SCRIPT='
	set -e
	ZIP_NAME=$1
	WP_ROOT=$2
	CHECK=/tmp/wp-preset-check
	ZIP=$(find "$WP_ROOT/wp-content/themes" -maxdepth 3 -type f \
		-name "$ZIP_NAME" -path "*/dist/*" | head -1)
	if [ -z "$ZIP" ]; then
		echo "could not find $ZIP_NAME inside the container" >&2
		exit 1
	fi
	rm -rf "$CHECK"
	mkdir -p "$CHECK/themes"
	unzip -q "$ZIP" -d "$CHECK/themes"
	DIR=$(find "$CHECK/themes" -mindepth 1 -maxdepth 1 -type d | head -1)
	SLUG=$(basename "$DIR")
	cat > "$CHECK/root.php" <<"PHP"
<?php
WP_CLI::add_hook( "after_wp_load", function () {
	register_theme_directory( "/tmp/wp-preset-check/themes" );
	delete_site_transient( "theme_roots" );
	register_shutdown_function( function () {
		delete_site_transient( "theme_roots" );
	} );
} );
PHP
	# Through the environment: wp eval takes no positional arguments.
	FOUND=$(WP_PRESET_SLUG="$SLUG" wp --path="$WP_ROOT" --require="$CHECK/root.php" eval \
		"echo wp_get_theme( getenv( \"WP_PRESET_SLUG\" ) )->get_stylesheet_directory();")
	if [ "$FOUND" != "$DIR" ]; then
		echo "$SLUG resolved to $FOUND, not the unpacked zip at $DIR" >&2
		exit 1
	fi
	# Theme Check exits 1 for a REQUIRED finding and also for "theme not found",
	# so its status alone cannot say whether it ran. Report it on a marker line
	# and let the caller decide from the payload. The JSON has no trailing
	# newline, so the marker starts with one to land on a line of its own.
	set +e
	wp --path="$WP_ROOT" --require="$CHECK/root.php" theme-check run "$SLUG" --format=json
	printf "\nwp-preset-theme-check-exit:%s\n" "$?"
'

log "Running checks..."
if [ "$KIND" = plugin ]; then
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
	OUT=$(wpenv_disposable run cli sh -c "
		set -e
		ZIP=\$(find $WP_ROOT/wp-content/$CONTENT_DIR -maxdepth 3 -type f \
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
else
	# stderr too: wp-env echoes the script there, and that is also where every
	# diagnostic lands. The payload and the marker are matched by whole line,
	# which nothing in the echoed script is.
	OUT=$(wpenv_disposable run cli sh -c "$THEME_SCRIPT" sh "$ZIP_NAME" "$WP_ROOT" 2>&1) \
		&& RUN_STATUS=0 || RUN_STATUS=$?
fi

# A failure here means the check never ran: the zip was not found, the unzip
# failed, or wp-cli errored. That is not a clean project, and reporting it as
# one is the worst thing this script could do — in JSON mode an empty payload is
# indistinguishable from a pass. Plugin Check's own exit code is always 0, and
# the theme script reports Theme Check's on a marker line instead, so a non-zero
# status here can only mean the infrastructure broke.
if [ "$RUN_STATUS" -ne 0 ]; then
	echo "check.sh: $TOOL did not run (exit $RUN_STATUS)." >&2
	# wp-env echoes the whole script it is about to run before any error, so a
	# plain tail shows that echo rather than the cause. Keep the lines that
	# actually diagnose it.
	printf '%s\n' "$OUT" \
		| grep -vE "^(ℹ Starting|✔ Ran)" \
		| grep -iE "error|fatal|failed|not found|cannot|no such|could not|resolved to" \
		| tail -10 >&2 || printf '%s\n' "$OUT" | tail -10 >&2
	exit "$RUN_STATUS"
fi

# wp-env wraps output in its own status lines. Strip them.
OUT=$(printf '%s\n' "$OUT" | sed '/^ℹ Starting /d; /^✔ Ran /d; /^✖ /d')

# Belt and braces: a zero status with no recognisable output means something
# changed upstream. Fail rather than print an empty array.
if [ -z "${OUT//[[:space:]]/}" ]; then
	echo "check.sh: $TOOL produced no output. It may have failed silently." >&2
	exit 1
fi

# --- Theme Check --------------------------------------------------------------
#
# Unlike Plugin Check, Theme Check returns a verdict: it exits 1 when any
# finding is REQUIRED and 0 otherwise. This script passes that through in both
# modes. Its items carry only a severity and a sentence — no file, no line, no
# code — so there is nothing to filter on and nothing to ignore by code.
if [ "$KIND" = theme ]; then
	TC_EXIT=$(printf '%s\n' "$OUT" | sed -n 's/^wp-preset-theme-check-exit:\([0-9]*\)$/\1/p' | tail -1)
	PAYLOAD=$(printf '%s\n' "$OUT" | grep -o '^\[.*\]$' | head -1 || true)
	# "Theme not found" and a crash also exit 1, so the status only counts when
	# a well-formed array came with it. An empty or unparseable payload is never
	# turned into a pass.
	VALID=1
	[ -n "$PAYLOAD" ] || VALID=0
	case "$TC_EXIT" in 0|1) ;; *) VALID=0 ;; esac
	if [ "$VALID" = 1 ] && ! printf '%s' "$PAYLOAD" \
		| php -r 'exit(is_array(json_decode(stream_get_contents(STDIN), true)) ? 0 : 1);' 2>/dev/null; then
		VALID=0
	fi
	if [ "$VALID" = 0 ]; then
		echo "check.sh: Theme Check did not produce a result (exit ${TC_EXIT:-unknown})." >&2
		printf '%s\n' "$OUT" | grep -v '^wp-preset-theme-check-exit:' | tail -10 >&2
		exit 1
	fi

	# Placeholders the scaffold ships so the automated check passes. Theme Check
	# cannot tell them from the real thing; a human reviewer can.
	PLACEHOLDERS=()
	# -a: the marker sits in a PNG text chunk, and BSD grep will not match
	# inside a file it has decided is binary.
	LC_ALL=C grep -aqs 'wp-preset placeholder' "$ROOT/screenshot.png" \
		&& PLACEHOLDERS+=("screenshot.png is the scaffold's blank image. Replace it with a 1200x900 capture of the theme.")
	grep -qs '^Short description\. No more than 150 characters\.$' "$ROOT/readme.txt" \
		&& PLACEHOLDERS+=("readme.txt still has the template's description.")

	if [ "$FORMAT" = strict-json ]; then
		printf '%s\n' "$PAYLOAD"
		for p in ${PLACEHOLDERS+"${PLACEHOLDERS[@]}"}; do
			echo "check.sh: placeholder: $p" >&2
		done
		exit "$TC_EXIT"
	fi

	# Severity order, most serious first, then a count per severity. Theme Check
	# prints in check order, which buries the one REQUIRED line among thirty
	# RECOMMENDED ones on a classic theme.
	printf '%s' "$PAYLOAD" | php -r '
		$items = json_decode( stream_get_contents( STDIN ), true );
		$rank  = array( "REQUIRED" => 0, "WARNING" => 1, "RECOMMENDED" => 2, "INFO" => 3 );
		$by    = function ( $i ) use ( $rank ) {
			return $rank[ $i["type"] ] ?? 4;
		};
		usort( $items, function ( $a, $b ) use ( $by ) {
			return $by( $a ) <=> $by( $b );
		} );
		$counts = array();
		foreach ( $items as $i ) {
			$type            = "" === $i["type"] ? "NOTE" : $i["type"];
			$counts[ $type ] = ( $counts[ $type ] ?? 0 ) + 1;
			$lines           = explode( "\n", wordwrap( $i["value"], 78 ) );
			printf( "%-12s %s\n", $type, array_shift( $lines ) );
			foreach ( $lines as $line ) {
				printf( "%-12s %s\n", "", $line );
			}
		}
		$summary = array();
		foreach ( $counts as $type => $n ) {
			$summary[] = $n . " " . $type;
		}
		echo "\n", implode( ", ", $summary ), "\n";
	'

	echo
	if [ "$TC_EXIT" = 0 ]; then
		echo "No REQUIRED findings. This theme would pass the automated half of"
		echo "wordpress.org review."
	else
		echo "REQUIRED findings block a wordpress.org submission."
	fi
	if [ ${#PLACEHOLDERS[@]} -gt 0 ]; then
		echo
		echo "Theme Check cannot see these, but a reviewer will:"
		for p in "${PLACEHOLDERS[@]}"; do
			echo "  - $p"
		done
	fi
	cat <<'EOF'

These are findings to assess, not a task list.

REQUIRED blocks a submission. WARNING needs a look. RECOMMENDED and INFO are
suggestions, many of them for features a given theme has no use for: adding
code to silence each one makes the theme worse, not better.

To hand these to an agent instead:

    composer check -- --json > findings.json
EOF
	exit "$TC_EXIT"
fi

# --- Plugin Check -------------------------------------------------------------

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
