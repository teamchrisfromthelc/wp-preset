<?php
/**
 * Footer template.
 *
 * @package WpProject
 */

declare( strict_types=1 );

?>
<footer class="site-footer">
	<p>
		<?php
		printf(
			/* translators: %s: site name */
			esc_html__( '&copy; %s', 'wp-project' ),
			esc_html( get_bloginfo( 'name' ) )
		);
		?>
	</p>
</footer>

<?php wp_footer(); ?>
</body>
</html>
