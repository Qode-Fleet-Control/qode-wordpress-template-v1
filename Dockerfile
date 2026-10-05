# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry.
#
# WordPress on FrankenPHP (a Caddy-based PHP app server). Core is downloaded at build
# time with wp-cli (WP_VERSION, checksum-verified) — the repo keeps only what is yours:
# wp-content/ and the env-driven wp-config.php. docker/entrypoint.sh waits for MariaDB,
# runs `wp core install` on the first start and serves 0.0.0.0:$PORT, the PORT read
# from the environment when the container STARTS.
FROM dunglas/frankenphp:1-php8.4-bookworm AS runtime
ARG WP_VERSION=7.1.2
ARG WP_CLI_VERSION=2.12.0
RUN install-php-extensions mysqli gd exif intl zip \
 && printf 'memory_limit=512M\nupload_max_filesize=64M\npost_max_size=64M\n' > "$PHP_INI_DIR/conf.d/zz-wordpress.ini" \
 && curl -fsSL -o /usr/local/bin/wp "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
 && chmod +x /usr/local/bin/wp \
 && useradd -r -u 10001 -d /app app \
 && mkdir -p /app && chown app:app /app /config/caddy /data/caddy
WORKDIR /app
USER app
# wp-cli's cache stays out of the docroot.
ENV WP_CLI_CACHE_DIR=/tmp/wp-cli-cache
RUN wp core download --version="$WP_VERSION" --skip-content --path=/app
COPY --chown=app:app wp-config.php ./
COPY --chown=app:app wp-content ./wp-content
# The entrypoint lives outside the docroot (/app is served as is).
COPY docker/entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
RUN mkdir -p private wp-content/uploads
ARG BUILD_ID=""
# private/ (the generated salts) sits in the docroot, beside wp-config.php: never serve it.
ENV PORT=8080 SERVER_ROOT=/app CADDY_SERVER_EXTRA_DIRECTIVES="respond /private/* 404" BUILD_ID=$BUILD_ID
EXPOSE 8080
ENTRYPOINT ["wordpress-entrypoint.sh"]
