#!/bin/sh
# Container start: salts, wait for MariaDB, install WordPress on the first start (no
# browser wizard), then serve on 0.0.0.0:$PORT — the PORT read from the environment now.
set -e

mkdir -p private wp-content/uploads
if [ ! -s private/salts.php ]; then
  php -r '$k = []; foreach (["AUTH_KEY","SECURE_AUTH_KEY","LOGGED_IN_KEY","NONCE_KEY","AUTH_SALT","SECURE_AUTH_SALT","LOGGED_IN_SALT","NONCE_SALT"] as $n) { $k[$n] = bin2hex(random_bytes(32)); } echo "<?php\nreturn " . var_export($k, true) . ";\n";' > private/salts.php
  echo "entrypoint: generated private/salts.php"
fi

echo "entrypoint: waiting for the database at ${WORDPRESS_DB_HOST:-db}"
i=0
until php -r 'mysqli_report(MYSQLI_REPORT_OFF); $h = getenv("WORDPRESS_DB_HOST") ?: "db"; $p = 3306; if (str_contains($h, ":")) { [$h, $p] = explode(":", $h, 2); } exit(@mysqli_connect($h, getenv("WORDPRESS_DB_USER") ?: "wordpress", getenv("WORDPRESS_DB_PASSWORD") ?: "wordpress", getenv("WORDPRESS_DB_NAME") ?: "wordpress", (int) $p) ? 0 : 1);'; do
  i=$((i + 1))
  if [ "$i" -ge 90 ]; then echo "entrypoint: database not reachable after 180s" >&2; exit 1; fi
  sleep 2
done

if ! wp core is-installed 2>/dev/null; then
  url="${FLEET_APP_URL:-http://localhost:${PORT:-8080}}"
  pass="${WORDPRESS_ADMIN_PASSWORD:-}"
  [ -n "$pass" ] || pass="$(php -r 'echo bin2hex(random_bytes(8));')"
  wp core install --url="$url" --title="${WORDPRESS_SITE_TITLE:-WordPress}" \
    --admin_user="${WORDPRESS_ADMIN_USER:-admin}" --admin_password="$pass" \
    --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" --skip-email
  if [ -z "${WORDPRESS_ADMIN_PASSWORD:-}" ]; then
    echo "entrypoint: admin user '${WORDPRESS_ADMIN_USER:-admin}', generated password: $pass"
  fi
  # Pretty permalinks (FrankenPHP routes unknown paths to index.php).
  wp rewrite structure '/%postname%/' >/dev/null
fi

export SERVER_NAME=":${PORT:-8080}"
exec frankenphp run --config /etc/frankenphp/Caddyfile
