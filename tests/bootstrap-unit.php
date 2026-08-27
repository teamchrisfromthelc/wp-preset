<?php
/**
 * Bootstrap for unit tests.
 *
 * No WordPress, no database. WP functions are mocked with WP_Mock, so these run
 * anywhere in milliseconds. Anything needing real WP behaviour (the database,
 * the query loop, core hooks actually firing) belongs in tests/integration/.
 *
 * @package WpProject
 */

declare( strict_types=1 );

$wp_project_autoload = __DIR__ . '/../vendor/autoload.php';

if ( ! file_exists( $wp_project_autoload ) ) {
	fwrite( STDERR, "Run 'composer install' before running the tests.\n" );
	exit( 1 );
}

// WP_Mock relies on Patchwork to redefine functions, which must be loaded
// before the code under test is autoloaded.
require_once $wp_project_autoload;

// Constants the code under test expects at include time. Unit tests never load
// WordPress or the entry point, so anything the entry point defines has to be
// stubbed here. Add project-specific ones alongside these.
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __DIR__ ) . '/' );
}

// Matches the entry point: plugin_dir_path() in a plugin, get_template_directory()
// in a theme. Both resolve to the project root with a trailing slash.
if ( ! defined( 'WP_PROJECT_DIR' ) ) {
	define( 'WP_PROJECT_DIR', dirname( __DIR__ ) . '/' );
}

WP_Mock::bootstrap();
