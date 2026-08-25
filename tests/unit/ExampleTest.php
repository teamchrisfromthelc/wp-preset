<?php
/**
 * Example unit test.
 *
 * Unit tests run with no WordPress loaded, so test pure logic here: parsing,
 * validation, formatting, calculations. Anything calling a WP function belongs
 * in tests/integration/.
 *
 * @package WpProject
 */

declare( strict_types=1 );

namespace WpProject\Tests\Unit;

use Yoast\PHPUnitPolyfills\TestCases\TestCase;

/**
 * Demonstrates the unit test shape.
 */
class ExampleTest extends TestCase {

	/**
	 * The harness itself works.
	 *
	 * @return void
	 */
	public function test_harness_runs() {
		$this->assertTrue( true );
	}

	/**
	 * Example of testing pure logic with a data provider.
	 *
	 * @dataProvider data_slugs
	 *
	 * @param string $input    Raw input.
	 * @param string $expected Expected slug.
	 * @return void
	 */
	public function test_slugify( $input, $expected ) {
		$actual = strtolower( trim( preg_replace( '/[^A-Za-z0-9]+/', '-', $input ), '-' ) );
		$this->assertSame( $expected, $actual );
	}

	/**
	 * Data provider for test_slugify().
	 *
	 * @return array<string, array{0: string, 1: string}>
	 */
	public static function data_slugs() {
		return array(
			'simple'    => array( 'Hello World', 'hello-world' ),
			'punctuation' => array( 'Acme & Co.', 'acme-co' ),
			'already slug' => array( 'already-a-slug', 'already-a-slug' ),
		);
	}
}
