# Revisión de cambios de Codex para la Entrega 3

**Fecha de revisión:** 21/10/2026. **Sistema en funcionamiento:** rama de base `e3/integracion` y VMs del laboratorio. **Auditoría no desplegada:** [PR #1](https://github.com/camilodrn/nodosur-tas-grupo7/pull/1), rama `audit/e3-codex-revisada`. **Cierre seleccionado:** [PR #2](https://github.com/camilodrn/nodosur-tas-grupo7/pull/2), rama `e3/cierre-tecnico`.

El PR grande de auditoría acumulaba 75 commits y 104 archivos de diferencia respecto de `e3/integracion` durante el examen. Mezcla documentación, evidencia, pruebas y cambios de Compose, MariaDB, firewall, HAProxy y systemd. No equivale a lo que está instalado en las VMs.

## Cambios seleccionados para el PR #2

| Archivo | Por qué se incorporó | Comprobación y límites |
|---|---|---|
| `README.md`, `ARQUITECTURA.md`, `INVENTARIO.md`, `docs/ENTREGA3.md` | Corregir documentación aún orientada a E2: ahora Nodo Sur usa cinco VMs, HAProxy, dos WordPress y NFS | Sustentados en pruebas y observaciones de VM263, 268, 279, 308 y 310 |
| `docs/MATRIZ-FLUJOS-E3.md` y `evidencias/e3/*` | Distinguir tráfico permitido/denegado, distribución, failover, TLS, NFS y Docker realmente observados | No afirmar eventos DOWN/UP ni tiempos RTO que las capturas no preservan |
| `scripts/validate-web.sh` | Anteriormente utilizaba siempre `curl -k` y no fallaba por respuestas HTTP no esperadas | Script nuevo sin escrituras; requiere CA confiable, o `NODOSUR_INSECURE=1` solo como diagnóstico |
| `scripts/validate-dns.sh` | Comprobar destinos esperados y propagar fallo de DNS sobre UDP/TCP | Solo lectura; confirmar contra la zona efectiva |
| `scripts/validate-db-local.sh` | Corregir consulta a `mariadb.service` nativo de E2; E3 usa Docker | Nuevo script de lectura para VM279: verifica contenedor, healthcheck y volumen histórico, sin recrear nada |
| `pruebas/e3/carrito-coherencia.py` | Evitar mutaciones accidentales y mejorar limpieza si la respuesta se pierde tras una escritura | Exige `--permitir-escritura --producto ID`; no ejecutado nuevamente en producción |
| `scripts/audit-secrets.py` y `.gitignore` | Revisar candidatos a secretos y reducir inclusiones accidentales | Barrido heurístico sin garantías absolutas |
| `SECURITY.md` y guías de pruebas/historia | Diferenciar controles productivos, propuestas y material de E2 | Las mejoras productivas no se dan por instaladas |

La rama `e3/cierre-tecnico` se validó mediante clon limpio en Fedora: seis Compose válidos mediante el cliente, `bash -n` correcto, AST de scripts Python correcto, `--help` de carrito sin escrituras, y barrido heurístico de secretos con cero candidatos. Las **25 pruebas unitarias previas** pertenecen al árbol local auditado, **no a un nuevo ensayo de la rama de cierre**.

## Cambios técnicos propuestos, todavía NO instalados

| Cambio de Codex | Beneficio / hallazgo | Decisión para E3 |
|---|---|---|
| `configs/apache/nodosur-uploads.conf` | Impedir que Apache interprete PHP/CGI dentro del NFS compartido `uploads`. En ambos web se observaron `php_module` y handler global, sin bloqueo específico detectado. El servidor NFS arrojó **cero archivos .php*/.phtml/.phar** al momento de la búsqueda, pero eso no protege subidas futuras | **Prioridad preventiva.** Archivo candidato versionado por separado; validar Apache de forma aislada, mantener imágenes accesibles y aplicar solo con autorización, un backend a la vez y reversión |
| `compose/proxy/haproxy.prod.cfg` | Saneamiento de `Forwarded`/`X-Forwarded-*` y TLS mínimo 1.2 | Evaluar impacto en WordPress y hacer pruebas de validación antes de cualquier recarga |
| `compose/web2/compose.yaml`, ejemplo `wp-config` | Propone `WORDPRESS_DB_PASSWORD_FILE`. En web2 ya existe `/run/secrets/db_password` y su `wp-config.php` referencia ese archivo | No cambiar credenciales por suposición: aún no se comprobó toda la ruta de lectura efectiva |
| `compose/db-stage/compose.prod.yaml` | Declare `external: true` y nombre explícito del volumen `nodosur-db-staging_db_stage_data`, evitando crear inadvertidamente un volumen vacío | Recomendable en una adopción planificada; no modificar proyecto/volumen en producción ahora |
| `configs/firewall/*.sh` y unidades systemd nuevas | Cambia política y orden de cadenas DOCKER-USER | No reemplazar servicios ya activos sin ensayos en laboratorio aislado, acceso de recuperación y rollback |
| Migrar archivos ejecutados por systemd a `/opt/nodosur` | Reducir riesgo de código modificable en directorios de usuarios | Requiere nueva instalación y permisos; se pospone para no romper servicios |
| Cambios de staging, backups y timers | Mejor separación de entornos, checksum, fallos parciales y retención | Principalmente E4; no tocar backups y timers reales sin inventario |

## Evidencia y límites del análisis de Apache

- **Web1:** `php_module` activo y `docker-php.conf` contiene `SetHandler application/x-httpd-php`; no se detectó bloqueador de PHP en `.htaccess` raíz mediante patrones acotados; falta archivo específico de hardening en uploads.
- **Web2:** mismo módulo/handler PHP y sin `.htaccess` en `wp-content`/`uploads`; no se detectaron directivas de denegación en `.htaccess` raíz mediante esos patrones.
- **Servidor VM268:** búsqueda directa y completa según `find` de extensiones `.php*`, `.phtml` y `.phar` reportó **0 archivos** y no devolvió errores. El `find` anterior desde web1 mostró `Permission denied` sobre `lost+found` y **no era exhaustivo**.
- **No se subió ni ejecutó un PHP de prueba en la producción.** Ausencia de archivo y de controles detectados **no demuestra explotación**. Comprobar configuración Apache efectiva y sintaxis de cualquier hardening propuesto.

Referencias: [revisión web1](../evidencias/e3/apache-php-directivas-web1-20261021.txt), [revisión de ambos web](../evidencias/e3/apache-uploads-revision-web1-web2-20261021.txt), [barrido NFS y web2](../evidencias/e3/nfs-php-y-htaccess-web2-20261021.txt).

## Criterios para instalar cualquier corrección en las VMs

1. Comprobar un defecto o exposición real y definir exactamente qué mejora aporta a E3.
2. Verificar el estado del contenedor y su configuración **antes** del cambio; conservar archivos previos y la forma de restaurarlos.
3. Probar sintaxis y respuesta de la aplicación en entorno aislado y medir qué cambia.
4. Si afecta a WordPress, intervenir **un solo backend cada vez**, con el otro sano y con procedimientos de reversión acordados.
5. Nunca recrear o eliminar el volumen productivo de MariaDB, ni detener Docker/NFS/DB/HAProxy para una prueba de archivo.
6. Solo declarar desplegada una protección una vez comprobada en la VM de destino; hasta entonces documentarla como propuesta.

**Alcance general:** E3 ya dispone de pruebas de balanceo, continuidad con un backend caído, coherencia de datos/archivos y segmentación. Las medidas de endurecimiento adicionales deben mejorar eso sin comprometer la demostración del viernes.
