<?php
/**
 * @package Hello_WC_Runner
 */

class HelloTest extends WP_UnitTestCase {

	public function test_greeting_is_plain_string(): void {
		$this->assertSame( 'Hello, wc-runner!', hello_wc_runner_greeting() );
	}

	public function test_woocommerce_is_loaded(): void {
		$this->assertTrue( function_exists( 'wc_get_product' ) );
	}
}
