
/**
 * Theme supports a classic theme must opt into.
 *
 * Block themes get most of these implicitly from theme.json, which is why this
 * block ships only with the classic variant.
 *
 * @return void
 */
function wp_project_setup() {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'custom-logo' );
	add_theme_support( 'automatic-feed-links' );
	add_theme_support(
		'html5',
		array( 'search-form', 'comment-form', 'comment-list', 'gallery', 'caption', 'style', 'script' )
	);

	register_nav_menus(
		array(
			'primary' => __( 'Primary', 'wp-project' ),
		)
	);
}
add_action( 'after_setup_theme', 'wp_project_setup' );
