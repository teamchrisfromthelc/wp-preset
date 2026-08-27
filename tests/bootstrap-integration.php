<?php
/**
 * Bootstrap for integration tests.
 *
 * Boots real WordPress from the core test library, then loads this plugin
 * before WP finishes initializing.
 *
 * WP_TESTS_DIR is set automatically inside wp-env, so these run there rather
 * than on the host — the test library and the database both live in the
 * container. On the host, point WP_TESTS_DIR at a separate WordPress develop
 * checkout: export WP_TESTS_DIR=/path/to/wordpress-develop/tests/phpunit
 *
 * The --env-cwd path below uses the project's directory name, which wp-env
 * mounts as-is; it is not necessarily the slug.
 *
 * @package WpProject
 */

declare( strict_types=1 );

$wp_project_autoload = __DIR__ . '/../vendor/autoload.php';

if ( file_exists( $wp_project_autoload ) ) {
	require_once $wp_project_autoload;
}

$wp_project_tests_dir = getenv( 'WP_TESTS_DIR' );

if ( ! $wp_project_tests_dir ) {
	$wp_project_tests_dir = rtrim( sys_get_temp_dir(), '/\\' ) . '/wordpress-tests-lib';
}

$wp_project_functions = $wp_project_tests_dir . '/includes/functions.php';

if ( ! file_exists( $wp_project_functions ) ) {
	fwrite(
		STDERR,
		"Could not find the WordPress test library at {$wp_project_tests_dir}.\n" .
		"Integration tests run inside wp-env, not on the host:\n" .
		"  npx wp-env run tests-cli \\\n" .
		"    --env-cwd=wp-content/{plugins|themes}/<project-folder> \\\n" .
		"    composer test:integration\n" .
		"Or set WP_TESTS_DIR to a wordpress-develop/tests/phpunit checkout.\n"
	);
	exit( 1 );
}

require_once $wp_project_functions;

// KIND-SPECIFIC LOADER — setup.sh replaces this line.

require $wp_project_tests_dir . '/includes/bootstrap.php';
