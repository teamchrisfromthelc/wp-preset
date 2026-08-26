<?php
/**
 * Header template.
 *
 * @package WpProject
 */

declare( strict_types=1 );

?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<?php wp_head(); ?>
</head>

<body <?php body_class(); ?>>
<?php wp_body_open(); ?>

<header class="site-header">
	<?php if ( has_custom_logo() ) : ?>
		<?php the_custom_logo(); ?>
	<?php else : ?>
		<p class="site-title">
			<a href="<?php echo esc_url( home_url( '/' ) ); ?>" rel="home">
				<?php bloginfo( 'name' ); ?>
			</a>
		</p>
	<?php endif; ?>

	<?php
	wp_nav_menu(
		array(
			'theme_location' => 'primary',
			'fallback_cb'    => false,
		)
	);
	?>
</header>
