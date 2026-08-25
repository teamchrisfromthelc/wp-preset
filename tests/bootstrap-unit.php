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

// Constants the plugin expects at include time. Add project-specific ones here.
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', dirname( __DIR__ ) . '/' );
}

if ( ! defined( 'WP_PROJECT_PLUGIN_DIR' ) ) {
	define( 'WP_PROJECT_PLUGIN_DIR', dirname( __DIR__ ) . '/' );
}

WP_Mock::bootstrap();
