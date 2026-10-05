<?php
/**
 * WordPress configuration — fleet template.
 *
 * Unlike the stock wp-config-sample.php, everything comes from the environment, so this
 * file holds no secrets and is committed. Defaults match compose.yaml's MariaDB service.
 *
 * @package WordPress
 */

$fleet_env = static function ( string $name, string $default = '' ): string {
	$value = getenv( $name );
	return ( false === $value || '' === $value ) ? $default : $value;
};

// ** Database settings ** //
define( 'DB_NAME', $fleet_env( 'WORDPRESS_DB_NAME', 'wordpress' ) );
define( 'DB_USER', $fleet_env( 'WORDPRESS_DB_USER', 'wordpress' ) );
define( 'DB_PASSWORD', $fleet_env( 'WORDPRESS_DB_PASSWORD', 'wordpress' ) );
define( 'DB_HOST', $fleet_env( 'WORDPRESS_DB_HOST', 'db' ) );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// ** Authentication keys and salts ** //
// WORDPRESS_<KEY> from the environment, else the set docker/entrypoint.sh generates
// once into private/salts.php (a docker volume).
$fleet_salt_file = __DIR__ . '/private/salts.php';
$fleet_salts     = is_file( $fleet_salt_file ) ? (array) include $fleet_salt_file : array();
foreach ( array( 'AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY', 'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT' ) as $fleet_key ) {
	define( $fleet_key, $fleet_env( 'WORDPRESS_' . $fleet_key, $fleet_salts[ $fleet_key ] ?? 'put your unique phrase here' ) );
}

$table_prefix = $fleet_env( 'WORDPRESS_TABLE_PREFIX', 'wp_' );

define( 'WP_DEBUG', filter_var( $fleet_env( 'WORDPRESS_DEBUG', 'false' ), FILTER_VALIDATE_BOOLEAN ) );

// The fleet terminates TLS at its edge and forwards plain HTTP.
if ( 'https' === ( $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '' ) ) {
	$_SERVER['HTTPS'] = 'on';
}

// Site URL: the host each request arrived on, so one database answers at localhost, at
// 127.0.0.1 (the health check) and at the public fleet URL without canonical redirects.
// CLI runs (wp-cli) use FLEET_APP_URL, else http://localhost:$PORT.
if ( ! empty( $_SERVER['HTTP_HOST'] ) ) {
	$fleet_url = ( ( $_SERVER['HTTPS'] ?? '' ) === 'on' ? 'https' : 'http' ) . '://' . $_SERVER['HTTP_HOST'];
} else {
	$fleet_url = rtrim( $fleet_env( 'FLEET_APP_URL', 'http://localhost:' . $fleet_env( 'PORT', '8080' ) ), '/' );
}
define( 'WP_HOME', $fleet_url );
define( 'WP_SITEURL', $fleet_url );

// Core is pinned in the Dockerfile (WP_VERSION) and baked into the image: update it there.
define( 'AUTOMATIC_UPDATER_DISABLED', true );

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
