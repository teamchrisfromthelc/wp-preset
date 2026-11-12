#!/usr/bin/env bash
# test-integration.sh — run the integration tests once, in a WordPress that
# exists only for this run.
#
#   composer test:integration:docker
#   composer test:integration:docker -- --filter=ExampleTest
#
# Starts a disposable wp-env, runs `composer test:integration` in its tests-cli
# container, removes the environment and exits with PHPUnit's status. Options
# after -- go to PHPUnit.
#
# This is the one-shot path: nothing to start first, nothing left running
# after. For a tight edit-and-rerun loop, keep `npm run env:start` up and run
# the tests in it instead; README's Testing section has the command. Either
# way the tests run inside the container, because that is where wp-env puts the
# WordPress test library.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

for cmd in docker node npx php; do
	command -v "$cmd" >/dev/null 2>&1 || {
		echo "test-integration.sh: missing required tool: $cmd" >&2
		exit 1
	}
done

if ! docker info >/dev/null 2>&1; then
	echo "test-integration.sh: Docker is not running. Start Docker Desktop, then try again." >&2
	exit 1
fi

# The tests run against the code mounted from this checkout, including vendor/.
[ -f vendor/bin/phpunit ] || {
	echo "test-integration.sh: vendor/bin/phpunit is missing. Run composer install first." >&2
	exit 1
}

# The same signal build.sh and check.sh use: a theme declares "Theme Name:" in
# style.css. wp-env mounts the project under the matching wp-content directory,
# named for the project folder rather than the slug.
CONTENT_DIR=plugins
grep -qs 'Theme Name:' "$ROOT/style.css" && CONTENT_DIR=themes
PROJECT_DIR=$(basename "$ROOT")

# Registers the cleanup trap before anything starts.
# shellcheck source=bin/wp-env-disposable.sh
. "$ROOT/bin/wp-env-disposable.sh"
wpenv_disposable_init "$ROOT"

echo "Starting a disposable WordPress (first run pulls images and takes a few minutes)..."
if ! WP_ENV_OUT=$(wpenv_disposable start 2>&1); then
	echo "test-integration.sh: wp-env failed to start." >&2
	printf '%s\n' "$WP_ENV_OUT" | tail -20 >&2
	exit 1
fi

# Two separators: wp-env run consumes the first itself, and composer needs the
# second to hand what follows to PHPUnit rather than read it as its own option.
FORWARD=()
[ $# -eq 0 ] || FORWARD=(-- -- "$@")

# Not exec: the shell has to outlive PHPUnit for its trap to clean up.
wpenv_disposable run tests-cli \
	--env-cwd="wp-content/$CONTENT_DIR/$PROJECT_DIR" \
	composer test:integration ${FORWARD+"${FORWARD[@]}"}
