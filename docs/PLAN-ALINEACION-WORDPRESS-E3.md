# Plan de alineación controlada de WordPress E3 — antes de ejecutar cambios

**Estado:** planificación, **NO ejecutado**. Documentado el 21/10/2026 tras detectar en producción WordPress 7.1.3 (web1) y 7.1.2 (web2), ambos con `$wp_db_version=61833`. WooCommerce 11.1.0, los 5911 archivos de plugins y los 584 archivos de temas coinciden en hashes por árbol. **No afirmar todavía equivalencia integral de WordPress.**

## Por qué una misma imagen no produjo el mismo WordPress

Los Compose de ambas VMs usan `wordpress:7.1.2-php8.3-apache`, pero cada host hace bind mount persistente de todo `/var/www/html`. La imagen oficial WordPress permite actualizaciones automáticas dentro de ese almacenamiento; Docker Compose **no sincroniza** dos bind mounts ubicados en VMs diferentes. Véase [documentación oficial de la imagen](https://hub.docker.com/_/wordpress).

## Estado de respaldos comprobado

- **MariaDB VM279:** contenedor `nodosur-db-staging` running/healthy, volumen **`nodosur-db-staging_db_stage_data`**, timer diario activo. El respaldo de `2026-10-21 04:05 UTC`, `nodo_sur_final-20261021-040534.sql.gz`, pasó `sha256sum -c` y `gzip -t` ([evidencia](../evidencias/e3/validacion-backup-mariadb-20261021.txt)). **Esto no constituye restauración ensayada**, y debe generarse/verificarse una copia cercana al momento del cambio.
- **Web2 VM310:** respaldo privado del árbol local `/srv/nodosur/web2/html`, excluyendo `uploads` NFS, en `/var/backups/nodosur-e3/web2-html-pre-upgrade-20261021T175636Z.tar.gz`; tamaño 55.351.002 bytes, root:root 0600, `gzip -t`, `sha256sum -c` y rutas de `wp-config.php` / `version.php` verificadas ([evidencia](../evidencias/e3/respaldo-html-web2-pre-upgrade-20261021.txt)). Contiene **secretos en wp-config.php**, nunca compartir ni subir a GitHub. Es respaldo en el **mismo host**, no redundante ante pérdida de VM.
- **NFS uploads:** se comparte desde VM268. No se incluye en ese archivo tar; su protección y respaldos deben considerarse separadamente.

## Comprobaciones oficiales de la versión objetivo

- WordPress.org confirma que **7.1.3 fue publicada el 6 de octubre de 2026** como actualización de seguridad, con siete correcciones: https://wordpress.org/documentation/wordpress-version/version-7.1.3/.
- La [tabla oficial de versiones](https://wordpress.org/documentation/article/wordpress-versions/) registra **DB version 61833 tanto para 7.1.2 como para 7.1.3**, coincidiendo con los `wp_db_version` leídos en ambas VMs; todavía no se leyó el valor del esquema almacenado en MariaDB.
- Los núcleos de ambos WordPress reportaron `$wp_local_package` **no declarado**; esto por sí solo **no confirma el idioma de interfaz configurado en WordPress**. No descargar paquetes de idioma a ciegas.
- Artefacto oficial **candidato** para staging **solo en Fedora**: `https://wordpress.org/wordpress-7.1.3.tar.gz`. WordPress.org publica su SHA-1 en `https://wordpress.org/wordpress-7.1.3.tar.gz.sha1` con valor `491a78c7676b15dffcc69130c6054b8f49228a91` (consultado el 21/10/2026). **Descargado y verificado en Fedora**: la descarga oficial del tar.gz y su SHA-1 desde HTTPS WordPress.org terminó correctamente, `sha1sum -c` indicó OK, `gzip -t` no reportó errores y el `version.php` contenido declara 7.1.3 ([evidencia](../evidencias/e3/wordpress-713-paquete-oficial-fedora-20261021.txt)). Todavía no se ha copiado ni instalado en ninguna VM. El SHA-1 sirve para comparar con el checksum publicado por WordPress.org, **no para garantizar criptográficamente por sí solo ausencia de ataques**; usar HTTPS y conservar procedencia y digest SHA-256 local.
- La [guía oficial de actualización](https://wordpress.org/documentation/article/updating-wordpress/) exige respaldar y advierte que no se debe borrar `wp-content`, ni perder `wp-config.php` o personalizaciones al reemplazar core.

## Puertas de seguridad antes de un cambio

1. Confirmar en ambos nodos versiones, localidad/idioma del paquete y `$wp_db_version`; comprobar que el core 7.1.3 de referencia es íntegro frente a checksums del proveedor, no copiar a ciegas desde web1.
2. Comprobar salud de web1, MariaDB, NFS y HAProxy; verificar que el proveedor permite descargar/validar el **paquete oficial exacto** de WordPress 7.1.3 y cuál es su locale. No usar descargas `--insecure`.
3. Confirmar backup privado **recuperable** de los archivos del sitio de web2, incluir `wp-config.php` y metadata pero **excluir uploads NFS**; guardar o transferir otra copia por canal privado si se requiere cobertura ante pérdida completa de VM.
4. Generar o confirmar backup de MariaDB próximo al cambio y comprobar SHA-256 y compresión. Si hay que revertir BD, evaluar efectos sobre transacciones realizadas desde web1 entre el backup y el fallo: **no restaurar automáticamente toda la BD compartida** como rollback de un solo backend.
5. Documentar método de drenaje temporal de web2 en HAProxy y cómo reincorporarlo; no tocar web1, NFS ni MariaDB; identificar ventana/operador responsable y forma de recuperar SSH.
6. Verificar que se dispone de herramienta/método de actualización **verificado por WordPress.org o WP-CLI**, con versión **explícitamente `7.1.3`** y preservación de `wp-config.php`, `wp-content/plugins`, `wp-content/themes`, `wp-content/uploads` y personalizaciones; no reemplazar contenidos arbitrariamente.
7. Tras actualizar solamente web2, comprobar versión real, esquema declarado y si WordPress solicita actualizaciones de esquema, configuración Apache de uploads, HTTP 200 tienda/imagen y denegación 403 de PHP. Verificar que el tráfico vuelve a web1/web2 sin errores observados.
8. Si falla web2, **mantenerlo fuera de rotación**, preservar logs, evaluar restaurar **solo** sus archivos locales desde tar verificado, sin tocar la BD compartida ni el NFS. No ejecutar rollback automático o comandos destructivos basados solo en una respuesta 500.

## Reproducibilidad a futuro

- Igualdad semántica de Compose **sí se comprobó** (SHA-256 Fedora y VMs coincidentes): [evidencia](../evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt).
- Igualdad real del WordPress instalado **NO**: el core difiere, aunque los plugins/temas coinciden. Para corregir el problema de raíz, hay que **controlar explícitamente la versión del CMS como un artefacto desplegable**, más allá del tag de Docker.
- A largo plazo: plantear una imagen de aplicación propia, inmutable, identificada por digest, desplegada primero en backend de prueba y después al segundo con health checks; persistir fuera de la imagen únicamente los datos necesarios, uploads y secretos. No migrar a esta arquitectura a última hora antes de la defensa.

## Estado de ejecución

**La descarga oficial del paquete 7.1.3 se completó y verificó en Fedora. No se ha iniciado la actualización de ningún WordPress.** El respaldo web2 y la comprobación previa de respaldo SQL sí están completados; las condiciones restantes deben verificarse en vivo antes de modificar el core.
