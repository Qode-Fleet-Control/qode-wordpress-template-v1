# WordPress template

Provisioned from [`Qode-Fleet-Control/fleet-template-v1`](https://github.com/Qode-Fleet-Control/fleet-template-v1) — the fleet
lifecycle contract (`bin/`, `fleet.conf`, `compose.yaml`, deploy workflows) with WordPress
7.1 on top, served by FrankenPHP, with its own MariaDB. The site installs itself on first
start with wp-cli — no install wizard.

## Origin

    php -d memory_limit=512M wp-cli-2.12.0.phar core download --version=7.1.2 --path=core
    # wp-cli is WordPress's official CLI; run in a php8.4 container

Generated 2026-10-05 (WordPress 7.1.2, the current release; wp-cli 2.12.0). The repo keeps
only what is site-specific: `wp-content/` (the stock `index.php` files, `plugins/` with
Akismet and Hello Dolly, and `themes/twentytwentyfive`, the default theme) and an
env-driven `wp-config.php`. Core (`wp-admin/`, `wp-includes/`, `wp-*.php`) is not
committed: the Dockerfile downloads exactly `WP_VERSION` with wp-cli (checksum-verified).

## Run it

**On the fleet** — nothing to do: `bin/run` (docker runtime) does `docker compose build`
then `docker compose up --remove-orphans` in the foreground. That starts **MariaDB and the
app**: the fleet provides no MySQL, so `compose.yaml` always runs its own `db` service
(not under a profile), and the app waits for it (`depends_on: service_healthy`, plus a
connect loop in the entrypoint). On its first start the app runs `wp core install`, so
`HEALTH_PATH=/` (the front page) answers 200 without anyone touching the wizard. The
admin login is `admin` / `$WORDPRESS_ADMIN_PASSWORD` — or, when that is unset, a
generated password printed in the app log (`entrypoint: admin user 'admin', generated
password: …`).

**With docker**

    PORT=8080 bin/run              # or: docker compose up --build
    curl localhost:8080/

**Without docker** (PHP 8.x with mysqli, wp-cli as `wp`, and a MySQL/MariaDB you provide
via `WORDPRESS_DB_HOST/NAME/USER/PASSWORD`):

    FLEET_RUNTIME=process PORT=8080 bin/run
    # = wp core download --skip-content (into the repo root, gitignored);
    #   wp core install (admin/admin); php -S 0.0.0.0:$PORT

| step | process runtime | docker runtime |
|---|---|---|
| install | `wp core download --version=7.1.2 --skip-content --force` | — |
| build | `wp core install …` (once) | `docker compose build` |
| start | `php -S 0.0.0.0:$PORT` | `docker compose up --remove-orphans` |

## How it works

- `Dockerfile`: `dunglas/frankenphp:1-php8.4-bookworm` (+ mysqli, gd, exif, intl, zip;
  `memory_limit=512M`, 64M uploads), wp-cli, core downloaded at build, runs as non-root
  `app`. `ARG WP_VERSION` is the one place to upgrade core (auto-updates are off, since
  core is baked into the image).
- `docker/entrypoint.sh` (copied to `/usr/local/bin`, outside the docroot): generates the
  auth keys/salts once into `private/salts.php`, waits for the database, installs the
  site on the first start (and sets `/%postname%/` permalinks), then FrankenPHP's stock
  Caddyfile on `SERVER_NAME=":$PORT"`; `/private/*` is never served.
- `wp-config.php`: database from `WORDPRESS_DB_*` (defaults match the `db` service),
  salts from `WORDPRESS_<KEY>` or `private/salts.php`, `WORDPRESS_DEBUG`. `WP_HOME` /
  `WP_SITEURL` follow the Host of each request (https when the fleet edge sends
  `X-Forwarded-Proto: https`), so the same database answers at `localhost`, at
  `127.0.0.1` (the health check) and at the public fleet URL without canonical redirects.
- Volumes: `db-data` (MariaDB), `wp-uploads` (`wp-content/uploads`), `wp-private`
  (salts). `docker compose down` keeps them; `down -v` starts over.
- Other settings: `WORDPRESS_SITE_TITLE`, `WORDPRESS_ADMIN_USER`,
  `WORDPRESS_ADMIN_PASSWORD`, `WORDPRESS_ADMIN_EMAIL`, `WORDPRESS_TABLE_PREFIX`.

## Deviations from stock WordPress, and why

- Core not committed (fetched by version at build) — the repo stays your code, and core
  upgrades are a one-line change.
- `wp-content/themes`: only `twentytwentyfive` (the default theme) is kept, not the
  older `twentytwentyfour`/`twentytwentythree`.
- `wp-config.php` written for the environment instead of copied from
  `wp-config-sample.php`; `AUTOMATIC_UPDATER_DISABLED` set.
- Added `Dockerfile`, `docker/entrypoint.sh`, `compose.yaml`, `.dockerignore`,
  `.gitignore`, `fleet.conf`, `bin/`, `.github/workflows/`, `docs/fleet-lifecycle.md`.

## Verified

**Not verified yet.** The `docker compose build` / `verify.sh` run was never reached: on
2026-10-05 the shared docker host's disk sat at 0-2 GB free (98 GB volume at 99-100%)
for more than three hours, below the 6 GB gate builds wait for. Before trusting this
template, run `verify.sh <dir> <port>` (run, restart and stop must all pass).

What *was* checked: `migrate.py audit` → READY; `php -l` on every PHP file this template
added or changed, and `sh -n` on its shell scripts → clean.

See `docs/fleet-lifecycle.md` for the lifecycle scripts.
