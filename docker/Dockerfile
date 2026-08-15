# WordPress + WooCommerce image for both the demo web service and the
# PHPUnit test job. One image serves both roles — avoids the wordpress:cli
# sidecar's Alpine-UID-82-vs-Debian-UID-33 mismatch; WP-CLI is run instead
# via `docker compose exec -u www-data wordpress wp ...`.
#
# WP_BASE is the full upstream tag (e.g. wordpress:php8.3-apache or
# wordpress:6.5-php8.3-apache), computed by wc-runner from --wp-version /
# --php-version. Taking it whole keeps the "omitted --wp-version" tag-shape
# difference out of this file entirely.
ARG WP_BASE
FROM ${WP_BASE}

# mariadb-client: run-plugin-tests.sh creates wordpress_test directly.
# git: composer VCS-repository installs. unzip/less: wp-cli dependencies.
# gettext-base: envsubst, used to render wp-tests-config.php.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gettext-base \
        git \
        less \
        mariadb-client \
        unzip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# www-data's HOME (/var/www) is not writable, so give wp-cli an explicit
# cache dir it can use instead of warning on every download.
ENV WP_CLI_CACHE_DIR=/opt/wc-runner/.wp-cli-cache

COPY scripts/ /opt/wc-runner/
RUN chmod +x /opt/wc-runner/*.sh \
    && mkdir -p /opt/wc-runner/work /opt/wc-runner/.composer-cache /opt/wc-runner/.wp-cli-cache \
    && chown -R www-data:www-data /opt/wc-runner
