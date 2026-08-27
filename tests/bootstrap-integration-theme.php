/**
 * Activate this theme before the tests run.
 *
 * A theme has no entry point to require the way a plugin does — WordPress
 * loads functions.php itself, but only for the *active* theme, and the test
 * suite starts on whichever theme the test install defaults to. Without this
 * the theme's own hooks never fire and every test exercises a default theme.
 *
 * @return void
 */
function wp_project_manually_load_theme() {
	switch_theme( basename( dirname( __DIR__ ) ) );
}
tests_add_filter( 'muplugins_loaded', 'wp_project_manually_load_theme' );
