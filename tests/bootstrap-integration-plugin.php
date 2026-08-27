/**
 * Load this plugin before WordPress finishes booting.
 *
 * Plugins under test are not in the active-plugins option, so nothing else
 * loads them. muplugins_loaded fires before WordPress reads that option.
 *
 * @return void
 */
function wp_project_manually_load_plugin() {
	require dirname( __DIR__ ) . '/wp-project.php';
}
tests_add_filter( 'muplugins_loaded', 'wp_project_manually_load_plugin' );
