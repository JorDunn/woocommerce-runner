<?php
/**
 * PHPUnit bootstrap for hello-wc-runner.
 *
 * Loads wp-phpunit's scaffolding, then WooCommerce, then the plugin under
 * test, on muplugins_loaded — this is the shape wc-runner expects from
 * every plugin repo (see README.md § Plugin repo contract).
 *
 * @package Hello_WC_Runner
 */

$_tests_dir = getenv( 'WP_PHPUNIT__DIR' ) ?: dirname( __DIR__ ) . '/vendor/wp-phpunit/wp-phpunit';

require_once $_tests_dir . '/includes/functions.php';

/**
 * Loads WooCommerce, then this plugin, before WordPress loads regular
 * plugins.
 */
function _hello_wc_runner_manually_load_plugin(): void {
	require ABSPATH . 'wp-content/plugins/woocommerce/woocommerce.php';
	require dirname( __DIR__ ) . '/hello-wc-runner.php';
}
tests_add_filter( 'muplugins_loaded', '_hello_wc_runner_manually_load_plugin' );

require $_tests_dir . '/includes/bootstrap.php';
