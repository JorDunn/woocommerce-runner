<?php
/**
 * Plugin Name: Hello wc-runner
 * Description: Minimal reference plugin exercising the wc-runner PHPUnit contract.
 * Version: 1.0.0
 * Requires PHP: 8.2
 * Requires Plugins: woocommerce
 * License: GPL-2.0-or-later
 *
 * @package Hello_WC_Runner
 */

defined( 'ABSPATH' ) || exit;

/**
 * Trivial function the test suite exercises, standing in for real plugin logic.
 */
function hello_wc_runner_greeting(): string {
	return 'Hello, wc-runner!';
}
