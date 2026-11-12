# shellcheck shell=bash
# shellcheck disable=SC2016 # The single-quoted scripts are PHP and JS; their $ is theirs.
# wp-env-disposable.sh — a throwaway WordPress for one run of one command.
# Sourced by check.sh and test-integration.sh, never run on its own: the
# cleanup trap has to live in the caller's shell, because that is the process
# Ctrl-C and `kill` reach.
#
#   . bin/wp-env-disposable.sh
#   wpenv_disposable_init "$ROOT" [--no-tests]   # registers cleanup first
#   wpenv_disposable start                       # any wp-env command, run
#   wpenv_disposable run cli wp plugin list      # against this env only
#
# Why not the project's own environment (npm run env:start)? That one belongs
# to the developer: its database, its ports, the plugins they installed. A check
# that installs Plugin Check into it changes their site, and a cleanup that
# drops its volumes deletes their content. So each run gets its own:
#
# - Identity. wp-env names its work directory, and through it the Docker
#   Compose project, after the path of the config file. A config generated in a
#   fresh temp dir therefore gets containers, volumes and a network no other
#   environment shares. wp-env still runs from the project root, which is what
#   it resolves relative sources like "." against, so the project mounts at the
#   same path it does in the dev environment.
# - Ports. Two free ones, picked here, so it starts beside a running dev env
#   instead of failing on 8888.
# - End. An EXIT/INT/TERM trap, registered before anything starts, runs
#   `wp-env cleanup`: containers, volumes, network and work directory. Not
#   `destroy`, which also deletes every image the environment used, including
#   the mariadb and WordPress base images every other wp-env on the machine
#   shares. The only images removed are the ones Compose built and tagged for
#   this run alone; nothing else can use them, and keeping them would leave a
#   new set behind on every run. Base images and the build cache stay, so the
#   next run rebuilds from cache. A sweep by Compose project label follows,
#   because `cleanup` alone removes nothing when a Ctrl-C lands before `start`
#   has finished.
#
# No trap can catch SIGKILL, a crash of the shell itself or a reboot. Those
# leave the environment behind. The README explains how to find and remove it.

_wpenv_root=""
_wpenv_dir=""
_wpenv_port=""
_wpenv_tests_port=""
_wpenv_workdir=""
_wpenv_project=""
_wpenv_done=0

# Run wp-env against the disposable environment and nothing else.
#
# --config is what keeps every command away from the dev environment: without
# it, wp-env would act on the project's own .wp-env.json. The port variables are
# set on every call, not just on start, because Compose re-reads them each time
# it loads the generated file. Any port variable the developer exported for
# their own environment is dropped for the same reason: honouring WP_ENV_PORT
# here would bind this environment to the port their site is already using.
#
# The Compose project name matters most, because it decides which containers
# and volumes `start` reuses and `cleanup --force` deletes. Compose takes it
# from COMPOSE_PROJECT_NAME before the directory name, and fills that from env
# files (COMPOSE_ENV_FILES, or a .env) when the process does not set it. A
# developer who named their own site either way would hand that identity to
# this environment, and cleanup would delete their database. Clearing the
# variable is not enough, since an env file then supplies it, so every call
# sets it to this run's own name: Compose never lets an env file override a
# variable the process already has. That name is the one Compose would derive
# from the temp work directory anyway, and the one teardown sweeps by.
# COMPOSE_FILE, COMPOSE_PROFILES and COMPOSE_ENV_FILES are cleared for the same
# reason: nothing from the developer's Compose setup may shape this run.
#
# Until init knows the name, only the read-only `status` it uses to learn it
# may run.
wpenv_disposable() {
	local project_env
	if [ -n "$_wpenv_project" ]; then
		project_env="COMPOSE_PROJECT_NAME=$_wpenv_project"
	elif [ "${1:-}" = status ]; then
		project_env="-uCOMPOSE_PROJECT_NAME"
	else
		echo "wp-env-disposable: refusing 'wp-env $1' before the environment has its own project name." >&2
		return 1
	fi
	(
		cd "$_wpenv_root" &&
			env -u COMPOSE_FILE -u COMPOSE_PROFILES -u COMPOSE_ENV_FILES \
				-u WP_ENV_MYSQL_PORT -u WP_ENV_TESTS_MYSQL_PORT \
				-u WP_ENV_PHPMYADMIN_PORT -u WP_ENV_TESTS_PHPMYADMIN_PORT \
				"$project_env" \
				WP_ENV_PORT="$_wpenv_port" WP_ENV_TESTS_PORT="$_wpenv_tests_port" \
				npx wp-env --config "$_wpenv_dir/.wp-env.json" "$@"
	)
}

# Prepare the environment and register its cleanup. Nothing is started yet.
#
# --no-tests drops the tests site (its WordPress, CLI and database containers)
# for callers that only need the development one. That halves what has to start
# and stop.
wpenv_disposable_init() {
	local root="$1" tests=1 ports
	[ "${2:-}" = --no-tests ] && tests=0
	_wpenv_root="$root"

	if [ ! -f "$root/.wp-env.json" ]; then
		echo "wp-env-disposable: no .wp-env.json in $root to base the environment on." >&2
		return 1
	fi

	# Before anything exists that would need cleaning up, so there is no window
	# in which a Ctrl-C leaves something behind.
	trap '_wpenv_on_exit' EXIT
	trap '_wpenv_on_signal 2' INT
	trap '_wpenv_on_signal 15' TERM

	# Outside the checkout: nothing generated here belongs in the project, and
	# a config inside it would be picked up by the developer's own tooling.
	_wpenv_dir=$(mktemp -d "${TMPDIR:-/tmp}/wp-env-disposable-XXXXXX")

	if [ "$tests" = 1 ]; then
		cp "$root/.wp-env.json" "$_wpenv_dir/.wp-env.json"
	else
		# Decoded as objects, not arrays: an array round-trip turns an empty
		# "config": {} into [], which wp-env rejects.
		php -r '
			$j = json_decode( file_get_contents( $argv[1] ) );
			if ( ! is_object( $j ) ) {
				fwrite( STDERR, "wp-env-disposable: .wp-env.json is not a JSON object.\n" );
				exit( 1 );
			}
			$j->testsEnvironment = false;
			file_put_contents( $argv[2], json_encode( $j, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES ) );
		' "$root/.wp-env.json" "$_wpenv_dir/.wp-env.json"
	fi
	# wp-env looks for the override next to the config it was given, so a
	# developer's .wp-env.override.json — a different PHP or WordPress version,
	# say — has to travel with it for this environment to match theirs.
	if [ -f "$root/.wp-env.override.json" ]; then
		cp "$root/.wp-env.override.json" "$_wpenv_dir/.wp-env.override.json"
	fi

	# Ask the OS for two ports nothing is listening on. wp-env's own --auto-port
	# is no use here: it switches itself off whenever CI is set.
	ports=$(node -e '
		const net = require( "net" );
		const grab = () =>
			new Promise( ( resolve, reject ) => {
				const server = net.createServer();
				server.once( "error", reject );
				server.listen( 0, () => resolve( server ) );
			} );
		Promise.all( [ grab(), grab() ] ).then( ( servers ) => {
			console.log( servers.map( ( s ) => s.address().port ).join( " " ) );
			servers.forEach( ( s ) => s.close() );
		} );
	') || {
		echo "wp-env-disposable: could not find free ports." >&2
		return 1
	}
	read -r _wpenv_port _wpenv_tests_port <<<"$ports"

	# wp-env's work directory, and through it the Compose project name that
	# teardown needs. Asked for now, while the environment does not exist yet:
	# once `start` has written its compose file but not finished, `status` fails
	# with "Environment not initialized" too, and that is exactly the state a
	# Ctrl-C during startup leaves.
	_wpenv_workdir=$(wpenv_disposable status --json 2>/dev/null \
		| php -r '
			$j = json_decode( stream_get_contents( STDIN ), true );
			echo $j["installPath"] ?? "";
		' 2>/dev/null || true)
	case "$(basename "${_wpenv_workdir:-/}")" in
		wp-env-wp-env-disposable-*) ;;
		*)
			echo "wp-env-disposable: could not read wp-env's work directory from 'wp-env status'." >&2
			return 1
			;;
	esac
	# Compose lowercases the work directory's name and drops anything outside
	# [a-z0-9_-] to make a project name. Pinned from here on (see above).
	_wpenv_project=$(basename "$_wpenv_workdir" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
	case "$_wpenv_project" in
		wp-env-wp-env-disposable-*) ;;
		*)
			echo "wp-env-disposable: unexpected Compose project name '$_wpenv_project'." >&2
			_wpenv_project=""
			return 1
			;;
	esac
}

# Remove the environment. Safe to call more than once and before anything
# started; returns non-zero if something could not be removed.
wpenv_disposable_teardown() {
	[ "$_wpenv_done" = 1 ] && return 0
	_wpenv_done=1
	[ -n "$_wpenv_dir" ] && [ -d "$_wpenv_dir" ] || return 0

	# A second Ctrl-C would otherwise kill the cleanup halfway and leave exactly
	# what this exists to remove. An ignored signal is inherited by the commands
	# below, so they finish too.
	trap '' INT TERM

	local failed=0 unverified=0 workdir="$_wpenv_workdir" project="$_wpenv_project" kind left
	local log="$_wpenv_dir/cleanup.log"
	echo "Removing the disposable WordPress environment..." >&2

	# Init stopped before it knew the project, so nothing was started: every
	# call but `status` refuses to run without it.
	if [ -z "$project" ]; then
		rm -rf "$_wpenv_dir"
		return 0
	fi

	# The documented way first. It is not enough on its own: wp-env only
	# recognises an environment once `start` has finished, so after a Ctrl-C
	# during the first minute it refuses with "Environment not initialized" and
	# removes nothing. Its result is therefore not the verdict; what is left
	# afterwards is.
	wpenv_disposable cleanup --force >"$log" 2>&1 || true

	# Then everything Docker labelled with this run's project, in dependency
	# order: containers hold the network, volumes and images. Docker sets the
	# label when it creates each one, so this finds whatever an interrupted
	# start got as far as making. Images go too: Compose builds and tags them
	# for this project alone, so nothing else can use them, while the base
	# images and build cache they came from stay.
	for kind in container network volume image; do
		# A failed query is checked again below, where it counts.
		left=$(_wpenv_labelled "$kind" "$project") || continue
		[ -n "$left" ] || continue
		# shellcheck disable=SC2086 # One ID or name per word, by design.
		case "$kind" in
			container) docker rm -f $left ;;
			network) docker network rm $left ;;
			volume) docker volume rm $left ;;
			# By name, not ID: removing a name never deletes an image some
			# other tag still points at.
			image) docker image rm $left ;;
		esac >/dev/null 2>>"$log" || true
	done
	# An empty answer only means "gone" if Docker actually answered. A daemon
	# that stopped mid-run fails every query, and treating that as empty would
	# report a clean teardown while the volumes wait for it to come back.
	for kind in container network volume image; do
		if ! left=$(_wpenv_labelled "$kind" "$project"); then
			failed=1
			unverified=1
			echo "  could not ask Docker whether any ${kind}s are left" >&2
		elif [ -n "$left" ]; then
			failed=1
			echo "  $kind left behind: $(printf '%s' "$left" | tr '\n' ' ')" >&2
		fi
	done

	# Unverified, the work directory and generated config stay: they are what
	# `wp-env cleanup` needs to find this environment again once Docker is back.
	if [ "$unverified" = 1 ]; then
		tail -10 "$log" >&2
		echo "  kept for a retry: $_wpenv_dir and $workdir" >&2
		echo "  once Docker is running: (cd \"$_wpenv_root\" && COMPOSE_PROJECT_NAME=$project npx wp-env --config \"$_wpenv_dir/.wp-env.json\" cleanup --force)" >&2
		return 1
	fi

	# Init only accepts a work directory this script named, so this rm -rf can
	# never reach anywhere else.
	rm -rf "$workdir" 2>>"$log" || true
	if [ -e "$workdir" ]; then
		failed=1
		echo "  work directory left behind: $workdir" >&2
	fi

	[ "$failed" = 0 ] || tail -10 "$log" >&2
	rm -rf "$_wpenv_dir"
	return "$failed"
}

# IDs (or, for images, names) of one kind of Docker object carrying this
# project's Compose label. Fails when Docker does not answer, so a caller can
# tell "none left" from "could not tell".
_wpenv_labelled() {
	local filter="label=com.docker.compose.project=$2"
	case "$1" in
		container) docker ps -aq --filter "$filter" ;;
		network) docker network ls -q --filter "$filter" ;;
		volume) docker volume ls -q --filter "$filter" ;;
		image) docker image ls --filter "$filter" --format '{{.Repository}}:{{.Tag}}' ;;
	esac 2>/dev/null
}

_wpenv_on_exit() {
	local status=$?
	if ! wpenv_disposable_teardown; then
		# The caller's result still stands: a passing run stays a pass and a
		# failing one stays a failure. The leftovers are reported, not hidden.
		echo "wp-env-disposable: could not fully remove the disposable environment." >&2
		echo "Everything it created carries 'wp-env-disposable' in its name:" >&2
		echo "  docker ps -a --filter name=wp-env-disposable" >&2
		echo "  docker volume ls --filter name=wp-env-disposable" >&2
		echo "Remove those with docker rm -f and docker volume rm." >&2
	fi
	exit "$status"
}

# Leave through the EXIT trap, so cleanup lives in one place, with the status a
# shell reports for death by that signal.
_wpenv_on_signal() {
	exit $((128 + $1))
}
