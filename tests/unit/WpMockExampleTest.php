<?php
/**
 * Example unit test using WP_Mock.
 *
 * WP_Mock intercepts WordPress functions so you can unit test code that calls
 * them without loading WordPress. Use it to assert that your code escapes
 * output, registers hooks, and calls core functions with the right arguments.
 *
 * @package WpProject
 */

declare( strict_types=1 );

namespace WpProject\Tests\Unit;

use WP_Mock;
use WP_Mock\Tools\TestCase as WPMockTestCase;

/**
 * Demonstrates the WP_Mock test shape.
 */
class WpMockExampleTest extends WPMockTestCase {

	/**
	 * A mocked WP function returns what you tell it to.
	 *
	 * @return void
	 */
	public function test_mocked_function_return() {
		WP_Mock::userFunction( 'get_option' )
			->once()
			->with( 'wp_project_mode' )
			->andReturn( 'live' );

		$this->assertSame( 'live', get_option( 'wp_project_mode' ) );
	}

	/**
	 * Escaping helpers can be passed through for assertions on output.
	 *
	 * @return void
	 */
	public function test_escaping_is_applied() {
		WP_Mock::passthruFunction( 'esc_html' );

		$this->assertSame( 'Widget', esc_html( 'Widget' ) );
	}

	/**
	 * Asserting that an action is registered.
	 *
	 * @return void
	 */
	public function test_action_is_registered() {
		WP_Mock::expectActionAdded( 'init', 'wp_project_register_cpt' );

		add_action( 'init', 'wp_project_register_cpt' );

		// WP_Mock verifies its expectations in tearDown(); without an explicit
		// assertion PHPUnit marks the test risky, so assert the hooks directly.
		$this->assertHooksAdded();
	}

	/**
	 * Asserting that a filter is applied to a value.
	 *
	 * @return void
	 */
	public function test_filter_is_applied() {
		WP_Mock::onFilter( 'wp_project_title' )
			->with( 'raw' )
			->reply( 'filtered' );

		$this->assertSame( 'filtered', apply_filters( 'wp_project_title', 'raw' ) );
	}
}
