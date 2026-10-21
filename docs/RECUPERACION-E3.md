# Respaldos, recuperación y reversión E3

**Procedimientos propuestos, no ejecutados en VMs durante esta auditoría.** La evidencia histórica acredita una restauración aislada de DB de 52 tablas; no acredita recuperación integral ni RPO/RTO.

## Qué se respalda y qué falta

Los scripts productivos generan `/var/backups/nodosur/daily/nodo_sur_final-FECHA.sql.gz` y su `.sha256`. Usan dump desde el contenedor saludable, `single-transaction`, routines/triggers/events, compresión y permisos 0700/0600. El bloqueo `flock` evita ejecuciones simultáneas. El checksum es la última publicación: la réplica debe esperar que existan ambos archivos y validarlos antes de archivarlos.

Un dump con cero tablas o comando fallido no se publica. La referencia de 52 tablas genera advertencia si cambia; un plugin puede añadir tablas legítimamente y no debe impedir toda copia. La verificación estricta contra 52 se reserva para comparación con el estado E3. La consistencia depende de InnoDB y de evitar DDL durante el dump; no usar la opción como garantía para MyISAM. El timeout propuesto del servicio es 15 minutos y requiere ajuste según tamaño y carga reales.

El servicio base y el timer se añadieron como **propuesta**: diario a 03:00 UTC, hasta cinco minutos de dispersión, ejecución pendiente tras arranque con `Persistent=true`. No reemplazan el transporte remoto ni demuestran su frecuencia real. Un objetivo diario daría un RPO nominal de hasta aproximadamente 24 horas solo si cada copia termina bien, se replica y se supervisa; ese RPO no ha sido acreditado. RTO no medido.

El equipo reportó copia `nodo_sur_final-20261020-190237.sql.gz` en `archive` de VM268 con SHA-256/GZIP válidos y 52 tablas. Faltan ruta remota absoluta, comando de copia, cuenta, clave pública/restricciones, host key verificada, unidad/timer `nodosur-remote-backup-maintenance`, logs y política de retención. **No se creó una implementación ficticia de esos componentes.** Capturar versiones saneadas antes de declarar réplica reproducible.

Existe en VM268 un archivo privado de respaldo web `/var/backups/nodosur-remote/web/wordpress-files-20261019-205742.tar.gz` (59 MB, root:root `0600`): se verificó GZIP y el listado TAR registra entradas `uploads`, plugins, temas y un `wp-config.php`. **Sus 126 archivos regulares de uploads fueron comparados por SHA-256 con NFS actual sin diferencias**; no se ha probado restauración funcional ni hay evidencia de frecuencia de actualización. No incluir este TAR en Git: `wp-config.php` puede contener credenciales y salts. La copia secundaria definitiva en VM279 está verificada mediante SHA-256/GZIP, guardada como root:root 0600 en `/var/backups/nodosur/web-secondary/wordpress-files-20261019-205742.tar.gz`; reduce la dependencia de VM268 pero no protege frente a un fallo común del clúster. No se han verificado todavía grants recuperables ni el conjunto de configuración BIND/NFS y TLS. Deben custodiarse privadamente con permisos mínimos y una segunda copia en otro dominio de falla. El checksum detecta corrupción accidental, no autentica frente a quien pueda modificar archivo y manifiesto. Retención y alertas de espacio están pendientes; esta rama no elimina automáticamente respaldos.

La comparación adicional de [126 archivos uploads](../evidencias/e3/comparacion-sha256-uploads-20261020.txt) frente al TAR existente arrojó 0 faltantes, 0 extras y 0 diferencias SHA-256. Esto valida los archivos regulares a la fecha de la comprobación. Ahora existe una segunda copia íntegra en VM279, con permisos `root:root 0600` y sin cifrado adicional en reposo; protege frente a pérdida aislada de VM268, pero no frente a la pérdida conjunta del clúster. Custodiar `wp-config.php` y salts sin publicarlos en Git. La recuperación de WordPress + DB continúa sin ensayo funcional completo.

## Verificar una copia existente (solo lectura)

En el host que posee la copia y desde un checkout del repositorio:

```bash
python3 scripts/e3/verify-backup.py /ruta/privada/nodo_sur_final-FECHA.sql.gz --expected-tables 52
```

La herramienta exige manifiesto adyacente con el mismo basename, calcula SHA-256, lee GZIP hasta EOF y cuenta `CREATE TABLE` sin mostrar SQL. No hace una importación ni confirma datos funcionales. Si el esquema cambió de forma aprobada, omitir `--expected-tables` y registrar la nueva línea base. Verificar edad de la copia con `stat` y comparar con la frecuencia prevista.

## Ensayo de restauración de MariaDB aislado

Preparar en un host de recuperación aprobado una copia íntegra, imagen MariaDB compatible de digest conocido y espacio suficiente. Los nombres siguientes deben ser **nuevos y exclusivos** del ensayo. No usar `nodosur-db-staging`, su volumen ni la red de producción.

1. Crear un directorio privado y un archivo secreto de una línea generado fuera de Git. Preparar también `restore-client.cnf`, root:root 0600, con usuario root y esa contraseña correctamente escapada. No usar contraseña en la línea de comandos ni `set -x`.
2. Validar SHA/GZIP antes de cualquier importación. La imagen debe estar disponible localmente; no resolver un tag mutable como sustituto silencioso.
3. En la ventana del ensayo, configurar variables de operador y lanzar el contenedor sin red ni puertos:

```bash
# Sustituir rutas por archivos privados existentes y digest por uno validado.
restore_name=nodosur-restore-ensayo-UNICO
restore_volume=nodosur-restore-data-UNICO
restore_image='mariadb@sha256:DIGEST_VALIDADO'
restore_secret=/ruta/privada/restore-root.password
restore_client=/ruta/privada/restore-client.cnf
backup_file=/ruta/privada/nodo_sur_final-FECHA.sql.gz

docker volume create "$restore_volume"
docker run -d --name "$restore_name" --network none --restart no \
  --mount "type=volume,src=$restore_volume,dst=/var/lib/mysql" \
  --mount "type=bind,src=$restore_secret,dst=/run/secrets/root_password,readonly" \
  --mount "type=bind,src=$restore_client,dst=/run/secrets/client.cnf,readonly" \
  -e MARIADB_ROOT_PASSWORD_FILE=/run/secrets/root_password \
  -e MARIADB_ROOT_HOST=localhost -e MARIADB_DATABASE=nodo_sur_final \
  "$restore_image"
```

4. Esperar inicialización mediante `docker logs --tail 30 "$restore_name"` y `docker exec "$restore_name" healthcheck.sh --connect --innodb_initialized`. No importar mientras falla la salud. Verificar aislamiento: `docker inspect -f 'Red={{.HostConfig.NetworkMode}} Puertos={{json .HostConfig.PortBindings}}' "$restore_name"` debe mostrar `none` y sin puertos publicados.
5. Importar exclusivamente al contenedor aislado. No sustituir su nombre por el productivo:

```bash
set -o pipefail
gzip -cd -- "$backup_file" | docker exec -i "$restore_name" \
  mariadb --defaults-extra-file=/run/secrets/client.cnf nodo_sur_final
```

6. Comprobar cantidad de tablas, motores, conteos de entidades y consultas funcionales saneadas. Con prefijo real confirmado:

```bash
docker exec "$restore_name" mariadb --defaults-extra-file=/run/secrets/client.cnf \
  --batch --skip-column-names -e \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='nodo_sur_final' AND TABLE_TYPE='BASE TABLE';"
```

La captura histórica dio 52 tablas, 51 posts, 512 opciones y 4 usuarios. Esos conteos pertenecen a esa copia y pueden cambiar. No publicar filas, correos ni sesiones. Registrar tiempos y código de importación. Parar el ensayo después de validar; conservar volumen y evidencia según la política acordada. Esta guía no ordena borrar datos ni ejecutar `down -v`/`prune`.

## Ensayo aislado de extracción WordPress en VM279 (realizado)

Se extrajo el TAR privado a `/var/backups/nodosur/restore-web-check-20261021`, directorio nuevo `root:root 0700`, sin restaurar propietarios ni permisos originales. La verificación contó **10.313 archivos WordPress y 126 archivos uploads**, y confirmó la presencia de `wp-config.php` ([evidencia](../evidencias/e3/extraccion-aislada-wordpress-vm279-20261021.txt)). No se ejecutó WordPress ni se conectó al contenedor de recuperación MariaDB; el ensayo acredita recuperación de archivos, no funcionamiento integrado de la tienda. Se cotejó además el SHA-256 de **10.313 archivos extraídos con los contenidos en el TAR**, con **0 diferencias** ([misma evidencia](../evidencias/e3/extraccion-aislada-wordpress-vm279-20261021.txt)). El directorio conserva archivos potencialmente sensibles: restringir acceso y acordar su retención; no compartir contenido ni contraseñas.

## Recuperación integral y criterios de aceptación

Tras una pérdida real, recuperar primero datos en infraestructura aislada, sin sobrescribir la original:

1. DNS/configuraciones y redes según inventario; NFS desde copia verificada de uploads.
2. DB desde backup validado; reconstruir usuarios/grants mediante registros privados y credenciales custodiadas.
3. Ambos web con versiones compatibles, mismos salts, prefijo y URLs; comprobar NFS y permisos.
4. Proxy con certificado/clave custodiados, firewall y nombres correctos.
5. Verificar DNS, SAN/TLS, HTTP 200, imágenes, sesiones/carrito, acceso DB autorizado y denegado, y coherencia de pedidos. Después decidir el cutover en una ventana autorizada.

DB y uploads deben corresponder a un punto temporal compatible: registrar cómo se coordinó la copia o una pausa de escrituras. Sin esos artefactos no es defendible afirmar recuperación completa de la tienda. No exponer el clon al tráfico de usuarios durante el ensayo.

## Reversión de las correcciones auditadas

Antes de adoptar, guardar privadamente unidades/drop-ins, Compose, reglas `iptables-save`, configuración de BIND y mounts efectivos. Los archivos base del repositorio pueden consultarse con `git show 279466d:RUTA`; ello no sustituye respaldar diferencias reales de las VMs.

- **Web/proxy:** intervenir un web por vez; detener la unidad afectada en la ventana, restituir archivos previos verificados y reconciliar drop-ins. Ejecutar validaciones y `daemon-reload`, luego iniciar y comprobar HTTP. Mantener el backend sano atendiendo; no recrear datos.
- **Firewall:** retirar solo los saltos/cadenas `NODOSUR_*` del rol si se revierte al script anterior, después de restaurar su política autorizada. Restaurar un `iptables-save` completo puede sobreescribir reglas dinámicas actuales de Docker: no hacerlo a ciegas. Conservar acceso de consola y comprobar SSH/HTTP desde orígenes aprobados.
- **DNS:** volver al destino anterior únicamente si ese servicio está operativo y elegido para rollback; incrementar el serial de nuevo. No reducir el serial ni asumir que E2 en `.202` sigue disponible.
- **DB:** detener el servicio nuevo antes de iniciar cualquier instancia antigua. El volumen original se conserva y no se formatea. Un rollback a MariaDB nativa **no recupera las escrituras posteriores al cutover**: requeriría exportación/reconciliación validada y una decisión de recuperación en ventana; no se automatiza.
- **NFS:** no desmontar en caliente ni escribir uploads en una copia local divergente. Recuperar el servidor/export correcto y verificar ambos clientes. Cualquier migración de datos exige copia íntegra y coordinación de escrituras.
- **Timer:** deshabilitar únicamente el timer nuevo si se vuelve al plan previo; conservar copias existentes y reinstalar su planificación conocida.

Revertir commits locales no revierte VMs. Los cambios de esta rama no han tocado producción; su reversión inmediata consiste en no desplegarlos o revisar los commits, sin ejecutar operaciones sobre los datos.
