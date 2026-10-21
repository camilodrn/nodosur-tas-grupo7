# Revisión de Codex para el cierre de E3

**Fecha:** 21/10/2026. **Base del sistema funcionando:** `e3/integracion`; auditoría separada: [PR #1](https://github.com/camilodrn/nodosur-tas-grupo7/pull/1) (`audit/e3-codex-revisada`). Este documento es una **evaluación de diferencias**, no una autorización para instalar todo el PR.

La comparación de GitHub entre ambas ramas de origen mostró **75 commits y 104 archivos** de diferencia. Es una mezcla de evidencias y documentación útiles con cambios a Compose, iptables, systemd, MariaDB y respaldos. La suite local de Codex aprobó **25 pruebas**, pero varias usan dobles de Docker/iptables, y las VMs están operando con la configuración anterior.

## Qué aporta a E3

| Modificación propuesta | Evaluación técnica | Estado/decisión |
|---|---|---|
| README, arquitectura, inventario y evidencias E3 | El repositorio estable describía principalmente E2 e incluía cifras de solicitudes (10/5/5) no demostradas por el archivo histórico de ocho solicitudes. | **Integrada en esta rama:** documentación corregida y evidencias saneadas, sin tocar servicios |
| `scripts/validate-web.sh` | La versión E2 usaba siempre `curl -k`, imprimía estados sin exigir HTTP 200 y podía terminar con éxito pese a fallos de aplicación. La propuesta usa tiempos límite, retorno no cero, 301 y verificación TLS explícita. | **Incorporada solo al repositorio de cierre**: script de consulta, sin ejecución en VM; usar desde VPN con CA pública validada o modo diagnóstico claramente señalado |
| `scripts/validate-dns.sh` | La versión E2 mostraba registros, pero no comparaba destinos con valores esperados ni propagaba correctamente errores. La propuesta comprueba apex, www, DB y NS por UDP/TCP. | **Incorporada solo al repositorio de cierre**: lectura DNS, no modifica zona; verificar destinos esperados en la zona efectiva |
| `scripts/audit-secrets.py` | Revisa nombres sospechosos, patrones de claves y blobs alcanzables en Git, omitiendo valores sensibles de la salida. | **Incorporada solo al repositorio de cierre**; útil antes de publicar, sin confundir 0 candidatos con ausencia garantizada |
| `.gitignore` | La rama estable no ignoraba algunos respaldos/paquetes sensibles, cookies ni ficheros temporales Python. | **Incorporado al repositorio de cierre**: extensiones de respaldo y secretos adicionales, `__pycache__` y `/audit-artifacts/`; no sustituye escaneo ni revisión manual |
| `pruebas/e3/carrito-coherencia.py` | El script original necesitaba un archivo temporal local y escribía en el carrito sin confirmación del operador; también podía omitir la limpieza si se perdía la respuesta del POST. La propuesta selecciona un ID de producto y exige una bandera explícita, e intenta limpiar incluso ante respuesta perdida. | **Incorporado al repositorio de cierre**; no ejecutado en producción; la prueba sigue escribiendo temporalmente en WooCommerce solo si se autoriza |
| `scripts/validate-db-local.sh` | El script heredado de E2 miraba `mariadb.service` nativo, incompatible con el contenedor productivo E3. | **Reescrito para VM279**: solo inspecciona Compose, estado, salud y volumen `nodosur-db-staging_db_stage_data` con Docker; no modifica DB ni depende del helper no instalado de Codex |
| `compose/db-stage/compose.prod.yaml` | Añadir `external: true` y `name: nodosur-db-staging_db_stage_data` evita crear por error un volumen nuevo al cambiar nombre de proyecto/archivo. El volumen existente fue observado en VM279. | **Muy recomendable para futura adopción**, pero comprobar contra contenedor real y copia de seguridad; no renombrar datos |
| `compose/web2/compose.yaml`, `configs/wordpress/wp-config-e3.example.php` | Agrega `WORDPRESS_DB_PASSWORD_FILE` y un ejemplo PHP que lee el archivo privado; sin embargo, WordPress tiene `wp-config.php` persistente y la variable NO modifica automáticamente ese archivo. | **Revisión read-only VM310**: `/run/secrets/db_password` existe, no está vacío y `wp-config.php` legible **contiene referencia** al archivo; no modificar ahora. No se inspeccionó el valor ni se demostró el camino efectivo de ejecución ([evidencia](../evidencias/e3/apache-secretos-y-validadores-20261021.txt)) |
| `configs/apache/nodosur-uploads.conf` | Denegar PHP/CGI bajo `uploads` reduciría riesgo de ejecución de archivos subidos. | **Observado**: no está instalado en web1 ni web2; web1 no tiene `.htaccess` dentro de uploads; ambos Apache `Syntax OK`. No demuestra ejecución PHP. **Siguiente**: inspeccionar otros controles Apache vigentes antes de decidir instalar; no crear un archivo PHP ejecutable para probarlo en producción ([evidencia](../evidencias/e3/apache-secretos-y-validadores-20261021.txt)) |
| `compose/proxy/haproxy.prod.cfg` | Mínimo TLS 1.2, limpieza de encabezados `Forwarded`, `X-Forwarded-Host` y sustitución de `X-Forwarded-For`. | **Posible mejora E3**, validar parseo y flujo WordPress/HTTPS en una ventana acordada; no recargar en plena defensa |
| `configs/firewall/*` y nuevas unidades systemd de firewall | Cambia una política `DOCKER-USER` ya instalada y comprobada en web1/web2. Hay diferencias de interfaz, orden, rutas y fuentes autorizadas. | **No desplegar automáticamente**; requiere revisión de cadenas reales, pruebas con acceso de recuperación y rollback |
| Unidades systemd en `/opt/nodosur` | Endurecimiento de ownership, pero **todas las VMs** están hoy organizadas desde directorios `/home/USUARIO/nodosur-tas-grupo7`. | **Posponer** migración, no cambiar rutas antes de entrega |
| Reestructura de staging, timers y scripts de respaldo | Puede mejorar aislamiento, bloqueo, checksums y manejo de errores, pero producción DB usa un proyecto y volumen históricos y existen timers reales. | **Posponer a E4**, contrastar timers/unidades reales para no duplicar ni alterar copias |

## Advertencias detectadas en la documentación de Codex

- En el primer dictamen aparecía la idea de que las unidades de firewall genérico no existían; **las salidas posteriores demostraron que `nodosur-docker-firewall.service` sí existe, está activo y habilitado en web1 y web2**. No se debe reemplazar por considerarlo ausente.
- Parte de las guías de operación de la auditoría cita los nuevos nombres de unidades específicos `...-web1.service` / `...-web2.service`. No son los instalados; para diagnosticar en producción consultar primero `systemctl cat` y `systemctl status` del servicio **genérico**.
- El entorno auditado con `/opt/nodosur` y volumen declarado como externo **no es el entorno desplegado**. Debe distinguirse de la configuración real para no romper arranques.
- Las mejoras de WordPress web2 no se consideran adoptadas porque el `wp-config.php` bind-mounted podría seguir obteniendo sus credenciales de otra forma.
- Las pruebas de 25/25 dan confianza en lógica local, pero **no** prueban HAProxy real, permisos Apache, firewall kernel, salud NFS tras caída ni restauración integral.

## Criterios para aceptar un cambio técnico antes de E3

1. Explicar **qué defecto observable** resuelve en la plataforma real.
2. Comprobar **el estado actual** de las VMs sin mostrar credenciales; no sustituir un componente operativo basándose solo en código propuesto.
3. Definir prueba de aceptación concreta y consecuencia de fallo (HTTP/SSH/DB/NFS).
4. Guardar configuración previa y plan de reversión antes de modificar cualquier servicio.
5. Probar primero en entorno aislado; si el cambio afecta un backend, intervenir uno por vez con el otro sano.
6. Nunca modificar o recrear el volumen real `nodosur-db-staging_db_stage_data` sin un plan de conservación/restauración aprobado.

## Estado general

La documentación y las evidencias observadas se pueden incorporar sin riesgo de disponibilidad. Los validadores web/DNS/DB, la prueba de carrito con autorización obligatoria, la protección adicional `.gitignore` y el escáner heurístico se incorporaron al repositorio de cierre; **no se instalaron en las VMs**. El clon Fedora se actualizó, pasó `bash -n` para los validadores y `ast.parse` para Python; `--help` de carrito mostró las banderas sin escribir y `git status` quedó limpio. **No se han ejecutado** los nuevos validadores contra producción. **Ningún cambio de configuración productiva es condición previa para cerrar la documentación de E3.** Las mejoras a ejecutar deben elegirse solo si mejoran un criterio E3 y existe tiempo para probar y revertir.
