<?php
/**
 * Main template.
 *
 * WordPress falls back to this file for any request it has no more specific
 * template for, so a classic theme is invalid without it. Add index.php's
 * siblings — single.php, page.php, archive.php, 404.php — as you need them.
 *
 * @package WpProject
 */

declare( strict_types=1 );

get_header();
?>

<main id="primary" class="site-main">
	<?php
	if ( have_posts() ) {
		while ( have_posts() ) {
			the_post();
			?>
			<article id="post-<?php the_ID(); ?>" <?php post_class(); ?>>
				<header class="entry-header">
					<?php the_title( '<h2 class="entry-title">', '</h2>' ); ?>
				</header>

				<div class="entry-content">
					<?php the_content(); ?>
				</div>
			</article>
			<?php
		}

		the_posts_pagination();
	} else {
		?>
		<p><?php esc_html_e( 'Nothing found.', 'wp-project' ); ?></p>
		<?php
	}
	?>
</main>

<?php
get_footer();
