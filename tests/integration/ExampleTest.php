<?php
/**
 * Example integration test.
 *
 * Real WordPress is loaded, so WP functions, the database, hooks, and factories
 * are all available. Each test runs in a transaction that is rolled back.
 *
 * @package WpProject
 */

declare( strict_types=1 );

namespace WpProject\Tests\Integration;

use WP_UnitTestCase;

/**
 * Demonstrates the integration test shape.
 */
class ExampleTest extends WP_UnitTestCase {

	/**
	 * WordPress is actually loaded.
	 *
	 * @return void
	 */
	public function test_wordpress_is_loaded() {
		$this->assertTrue( function_exists( 'wp_insert_post' ) );
	}

	/**
	 * The factory creates real posts in the test database.
	 *
	 * @return void
	 */
	public function test_post_factory() {
		$post_id = self::factory()->post->create(
			array(
				'post_title'  => 'Test Item',
				'post_status' => 'publish',
			)
		);

		$post = get_post( $post_id );

		$this->assertInstanceOf( \WP_Post::class, $post );
		$this->assertSame( 'Test Item', $post->post_title );
	}

	/**
	 * Hooks fire as expected.
	 *
	 * @return void
	 */
	public function test_filter_applies() {
		add_filter( 'wp_project_example', fn( $value ) => $value * 2 );

		$this->assertSame( 10, apply_filters( 'wp_project_example', 5 ) );
	}
}
