<?php
/**
 * Autoloader wiring test.
 *
 * Guards the composer.json psr-4 map. Without it the plugin's require of
 * vendor/autoload.php succeeds while registering nothing, so classes in
 * includes/ never load — and every linter still passes, because they read
 * files directly rather than autoloading them.
 *
 * @package WpProject
 */

declare( strict_types=1 );

namespace WpProject\Tests\Unit;

use WpProject\Example;
use Yoast\PHPUnitPolyfills\TestCases\TestCase;

/**
 * Confirms includes/ is autoloadable.
 */
class AutoloadTest extends TestCase {

	/**
	 * A class in includes/ resolves without an explicit require.
	 *
	 * @return void
	 */
	public function test_includes_are_autoloaded() {
		$this->assertTrue(
			class_exists( Example::class ),
			'includes/ is not PSR-4 autoloaded. Check the "autoload" block in composer.json.'
		);
	}

	/**
	 * The namespace prefix matches the one composer.json maps.
	 *
	 * @return void
	 */
	public function test_namespace_prefix_matches_the_map() {
		$this->assertSame(
			'WpProject\Example',
			Example::class,
			'The class prefix and the psr-4 namespace have drifted apart.'
		);
	}
}
