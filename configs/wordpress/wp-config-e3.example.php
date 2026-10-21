<?php
/* Fragmento E3 para integrar ANTES de require wp-settings.php.
 * No es un wp-config.php completo. Mantener DB_NAME, DB_USER, table_prefix
 * y los ocho salts REALES idénticos entre web1/web2 fuera del repositorio.
 * Este ejemplo falla si el secreto no está disponible; no usa un valor por defecto.
 */
$passwordFile = getenv('WORDPRESS_DB_PASSWORD_FILE');
if (!$passwordFile || !is_readable($passwordFile)) {
    throw new RuntimeException('Falta el archivo secreto de MariaDB');
}
$dbPassword = rtrim(file_get_contents($passwordFile), "\r\n");
if ($dbPassword === '') {
    throw new RuntimeException('Secreto de MariaDB vacío');
}
define('DB_PASSWORD', $dbPassword);
unset($dbPassword);

/* Solo confiar en el proxy autorizado; no aceptar HTTPS de clientes directos.
 * Confirmar REMOTE_ADDR efectivo con la red Docker instalada.
 */
if (($_SERVER['REMOTE_ADDR'] ?? '') === '10.33.199.61'
    && ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
define('WP_HOME', 'https://nodosur07.tas');
define('WP_SITEURL', 'https://nodosur07.tas');
define('DISALLOW_FILE_EDIT', true);
