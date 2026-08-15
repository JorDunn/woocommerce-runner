#!/usr/bin/env bash
# Idempotent WooCommerce store provisioning. Runs as www-data inside the
# wordpress or test service, after the db is reachable.
#
# Usage: seed.sh <core|full>
#
#   core  WordPress + WooCommerce installed and version-pinned, mounted
#         plugins activated. Used by both --demo and default test mode.
#   full  Everything in "core" plus the storefront theme, WooCommerce
#         store pages, sample products, pretty permalinks, and the
#         optional object cache. Used by --demo only.
#
# Every step is guarded so re-running against a warm wp-data volume is
# fast and lands on the same end state. Reads WC_RUNNER_WC_VERSION,
# WC_RUNNER_PLUGINS, WC_RUNNER_WITH_CACHE, WC_RUNNER_PORT from the
# environment (set by compose.yaml from wc-runner's flags).
set -euo pipefail

LEVEL=${1:?usage: seed.sh <core|full>}

ADMIN_USER=admin
ADMIN_PASS=woocommerce-runner
SITE_URL="http://localhost:${WC_RUNNER_PORT:-8080}"

log() { echo "[seed.sh] $*" >&2; }

# --- 0. Stale object-cache drop-in from a prior --with-cache run ----------
# Without the cache profile there is no Valkey to connect to, and the
# drop-in makes every wp invocation fail before it could be disabled the
# polite way (`wp redis disable`) — remove the file directly.
if [[ ${WC_RUNNER_WITH_CACHE:-0} != 1 && -f /var/www/html/wp-content/object-cache.php ]]; then
    log "removing stale object-cache.php drop-in (no --with-cache this run)"
    rm -f /var/www/html/wp-content/object-cache.php
fi

# --- 1. Wait for the database ---------------------------------------------
log "waiting for database..."
db_ready=0
for _ in $(seq 1 60); do
    if wp db check --quiet 2>/dev/null; then
        db_ready=1
        break
    fi
    sleep 1
done
[[ $db_ready == 1 ]] || { log "database never became reachable"; exit 1; }

# --- 2. WordPress core ------------------------------------------------------
if ! wp core is-installed 2>/dev/null; then
    log "installing WordPress core..."
    wp core install \
        --url="$SITE_URL" \
        --title="woocommerce-runner" \
        --admin_user="$ADMIN_USER" \
        --admin_password="$ADMIN_PASS" \
        --admin_email="admin@wc-runner.local" \
        --skip-email
fi

# --- 3. WooCommerce, pinned to WC_RUNNER_WC_VERSION (empty = latest) ------
version_args=()
[[ -n ${WC_RUNNER_WC_VERSION:-} ]] && version_args=(--version="$WC_RUNNER_WC_VERSION")

if ! wp plugin is-installed woocommerce 2>/dev/null; then
    log "installing WooCommerce ${WC_RUNNER_WC_VERSION:-latest}..."
    wp plugin install woocommerce "${version_args[@]}"
elif [[ -n ${WC_RUNNER_WC_VERSION:-} ]] \
        && [[ "$(wp plugin get woocommerce --field=version)" != "$WC_RUNNER_WC_VERSION" ]]; then
    log "re-pinning WooCommerce to ${WC_RUNNER_WC_VERSION} (was $(wp plugin get woocommerce --field=version))..."
    wp plugin install woocommerce "${version_args[@]}" --force
fi
wp plugin activate woocommerce --quiet

# --- 4. Activate mounted plugins under test --------------------------------
if [[ -n ${WC_RUNNER_PLUGINS:-} ]]; then
    IFS=',' read -ra plugins <<<"$WC_RUNNER_PLUGINS"
    for p in "${plugins[@]}"; do
        log "activating plugin: $p"
        wp plugin activate "$p"
    done
fi

[[ $LEVEL == core ]] && exit 0

# --- 5. Storefront theme, for a browsable store ----------------------------
if [[ "$(wp theme list --status=active --field=name)" != "storefront" ]]; then
    log "installing storefront theme..."
    wp theme install storefront --activate
fi

# --- 6. WooCommerce store pages (Shop, Cart, Checkout, My Account) --------
if ! wp option get woocommerce_shop_page_id >/dev/null 2>&1; then
    log "creating WooCommerce store pages..."
    wp wc tool run install_pages --user="$ADMIN_USER"
fi

# --- 7. Skip onboarding, pin country/currency for reproducible demos ------
# The onboarding/task-list options are cosmetic and WC Admin sometimes
# refuses direct updates for them (varies by WC version) — never let one
# abort the seed.
wp option update woocommerce_onboarding_opt_in no --quiet || log "could not set woocommerce_onboarding_opt_in (ignored)"
wp option update woocommerce_task_list_hidden yes --quiet || log "could not set woocommerce_task_list_hidden (ignored)"
wp option update woocommerce_default_country US:CA --quiet
wp option update woocommerce_currency USD --quiet

# --- 8. Sample products, guarded by a marker option ------------------------
if ! wp option get wc_runner_sample_data_imported >/dev/null 2>&1; then
    log "importing sample products..."
    wp plugin install wordpress-importer --activate
    wp import wp-content/plugins/woocommerce/sample-data/sample_products.xml \
        --authors=create
    wp plugin deactivate wordpress-importer
    wp option add wc_runner_sample_data_imported 1
fi

# --- 9. Pretty permalinks, so the storefront doesn't 404 on product pages -
wp rewrite structure '/%postname%/' --hard

# --- 10. Optional object cache (Valkey speaks the Redis protocol) ---------
if [[ ${WC_RUNNER_WITH_CACHE:-0} == 1 ]]; then
    if ! wp plugin is-installed redis-cache 2>/dev/null; then
        log "installing redis-cache plugin..."
        wp plugin install redis-cache --activate
    fi
    wp plugin activate redis-cache --quiet
    wp redis enable --quiet 2>/dev/null || log "redis-cache already enabled"
fi

# --- 11. Banner -------------------------------------------------------------
# Plain stdout, not log(): `docker compose exec` inherits it straight
# through to wc-runner's terminal.
cat <<BANNER
------------------------------------------------------------
WooCommerce store ready
  Store:     ${SITE_URL}/
  wp-admin:  ${SITE_URL}/wp-admin/
  Login:     ${ADMIN_USER} / ${ADMIN_PASS}
------------------------------------------------------------
BANNER
