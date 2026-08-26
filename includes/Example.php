<?php
/**
 * Example autoloaded class.
 *
 * Delete this once you have real classes. It exists to show the wiring:
 * composer.json maps WpProject\ to includes/ via PSR-4, so this file must be
 * named Example.php to match the class name — not class-example.php, which is
 * the WordPress convention used everywhere outside includes/. phpcs.xml.dist
 * excludes this directory from WordPress.Files.FileName for that reason.
 *
 * @package WpProject
 */

declare( strict_types=1 );

namespace WpProject;

/**
 * Demonstrates the PSR-4 autoloader.
 */
class Example {

	/**
	 * Confirms the class was autoloaded.
	 *
	 * @return string
	 */
	public function greeting(): string {
		return __( 'Hello from WP Project.', 'wp-project' );
	}
}
