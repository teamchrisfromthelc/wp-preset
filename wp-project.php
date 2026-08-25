<?php
/**
 * Plugin Name:       WP Project
 * Description:       A WordPress plugin.
 * Version:           0.1.0
 * Requires at least: 6.5
 * Requires PHP:      8.0
 * Author:            Your Name
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       wp-project
 *
 * @package WpProject
 */

declare( strict_types=1 );

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'WP_PROJECT_VERSION', '0.1.0' );
define( 'WP_PROJECT_FILE', __FILE__ );
define( 'WP_PROJECT_DIR', plugin_dir_path( __FILE__ ) );
define( 'WP_PROJECT_URL', plugin_dir_url( __FILE__ ) );

$wp_project_autoload = WP_PROJECT_DIR . 'vendor/autoload.php';

if ( file_exists( $wp_project_autoload ) ) {
	require_once $wp_project_autoload;
}
