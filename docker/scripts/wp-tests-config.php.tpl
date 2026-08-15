<?php
// Rendered by run-plugin-tests.sh (envsubst) into
// /opt/wc-runner/wp-tests-config.php. Consumed by wp-phpunit via
// WP_PHPUNIT__TESTS_CONFIG — see vendor/wp-phpunit/wp-phpunit/includes/bootstrap.php
// in the plugin under test.

define( 'ABSPATH', '${ABSPATH}' );

$table_prefix = 'wptests_';

define( 'DB_NAME', '${DB_NAME}' );
define( 'DB_USER', '${DB_USER}' );
define( 'DB_PASSWORD', '${DB_PASSWORD}' );
define( 'DB_HOST', '${DB_HOST}' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

define( 'WP_TESTS_DOMAIN', 'localhost' );
define( 'WP_TESTS_EMAIL', 'admin@wc-runner.local' );
define( 'WP_TESTS_TITLE', 'woocommerce-runner Test Suite' );

define( 'WP_PHP_BINARY', 'php' );

define( 'WPLANG', '' );
