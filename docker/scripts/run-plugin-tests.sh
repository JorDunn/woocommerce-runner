#!/usr/bin/env bash
# Entrypoint for the disposable "test" compose service: seeds a throwaway
# WordPress + WooCommerce install, copies the plugin under test out of its
# read-only mount, installs its dev dependencies, and runs PHPUnit.
#
# Usage: run-plugin-tests.sh <plugin-basename> [phpunit args...]
#
# Exit code is whatever phpunit returns (`exec` at the end so nothing here
# rewrites it) — wc-runner propagates it unchanged via `docker compose run
# --rm test`, which is the tool's whole test-mode result contract.
set -euo pipefail

PLUGIN=${1:?usage: run-plugin-tests.sh <plugin-basename> [phpunit args...]}
shift

# --- 1. Cold wp-data volume: apache has never run, core was never copied -
if [[ ! -f /var/www/html/wp-load.php ]]; then
    echo "[run-plugin-tests.sh] cold wp-data volume, extracting core..." >&2
    cp -a /usr/src/wordpress/. /var/www/html/
    wp config create \
        --dbname="${WORDPRESS_DB_NAME:-wordpress}" \
        --dbuser="${WORDPRESS_DB_USER:-wordpress}" \
        --dbpass="${WORDPRESS_DB_PASSWORD:-wordpress}" \
        --dbhost="${WORDPRESS_DB_HOST:-db}" \
        --path=/var/www/html \
        --skip-check
fi

# --- 2. Seed the live store: WooCommerce + the plugins under test --------
/opt/wc-runner/seed.sh core

# --- 3. Dedicated test database ------------------------------------------
# Separate from "wordpress": wp-phpunit drops and recreates its tables on
# every run, so it must never touch the live store's database.
mysql -h "${WORDPRESS_DB_HOST:-db}" -u root -p"${MARIADB_ROOT_PASSWORD:-wc-runner}" \
    -e "CREATE DATABASE IF NOT EXISTS wordpress_test"

# --- 4. Writable copy of the plugin ---------------------------------------
# /mnt/plugins-src is read-only; this is how it coexists with `composer
# install`, which needs to write vendor/ and composer.lock.
work="/opt/wc-runner/work/${PLUGIN}"
rm -rf "$work"
cp -a "/mnt/plugins-src/${PLUGIN}" "$work"
cd "$work"

# --- 5. Dev dependencies ---------------------------------------------------
composer install --no-interaction --no-progress

# --- 6. Render wp-phpunit's DB config and hand off ------------------------
export ABSPATH=/var/www/html/
export DB_NAME=wordpress_test
export DB_USER=root
export DB_PASSWORD="${MARIADB_ROOT_PASSWORD:-wc-runner}"
export DB_HOST="${WORDPRESS_DB_HOST:-db}"
envsubst '${ABSPATH} ${DB_NAME} ${DB_USER} ${DB_PASSWORD} ${DB_HOST}' \
    < /opt/wc-runner/wp-tests-config.php.tpl \
    > /opt/wc-runner/wp-tests-config.php

export WP_PHPUNIT__TESTS_CONFIG=/opt/wc-runner/wp-tests-config.php
exec vendor/bin/phpunit "$@"
