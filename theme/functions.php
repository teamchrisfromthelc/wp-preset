<?php
/**
 * Theme bootstrap.
 *
 * @package WpProject
 */

declare( strict_types=1 );

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'WP_PROJECT_VERSION', '0.1.0' );
define( 'WP_PROJECT_DIR', get_template_directory() . '/' );
define( 'WP_PROJECT_URL', get_template_directory_uri() . '/' );

$wp_project_autoload = WP_PROJECT_DIR . 'vendor/autoload.php';

if ( file_exists( $wp_project_autoload ) ) {
	require_once $wp_project_autoload;
}

/**
 * Enqueue front-end assets.
 *
 * @return void
 */
function wp_project_enqueue_assets() {
	wp_enqueue_style(
		'wp-project',
		get_stylesheet_uri(),
		array(),
		WP_PROJECT_VERSION
	);
}
add_action( 'wp_enqueue_scripts', 'wp_project_enqueue_assets' );
