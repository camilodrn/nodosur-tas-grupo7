# Entrega 3 — Nodo Sur, Grupo 7

Entrega: **23-10-2026**. Consolidación/auditoría local: **20-10-2026**. Base Git `279466d`, rama de revisión `audit/e3-codex`, creada desde `e3/integracion` en ese mismo commit. No se accedió por SSH, no se modificó infraestructura ni se ejecutaron pruebas con escrituras sobre la aplicación.

## Arquitectura implementada según el equipo

| VM | Función | Administración | Interna |
|---|---|---|---|
| 268 | DNS BIND9, NFS, respaldos remotos | 10.33.195.205 | 10.33.199.59 |
| 263 | WordPress/WooCommerce web1 Docker | 10.33.195.202 | 10.33.199.58 |
| 310 | WordPress/WooCommerce web2 Docker | 10.33.195.208 | 10.33.199.62 |
| 279 | MariaDB Docker | 10.33.195.226 | 10.33.199.60 |
| 308 | HAProxy Docker con HTTPS | 10.33.195.194 | 10.33.199.61 |

BIND resuelve `nodosur07.tas` y `www` al proxy `.194`. HAProxy redirige HTTP a HTTPS y balancea roundrobin a `.58:18081` y `.62:18080`; HEAD `/` con Host de la tienda y status 200 controla salud. Ambos web usan MariaDB `.60:3306` y uploads NFS compartidos. El certificado es autofirmado con SAN para ambos nombres según el registro del equipo; falta salida pública saneada de SAN/vigencia.

## Evidencia disponible y su alcance

No se modificaron ni recrearon los archivos de pruebas originales. Las afirmaciones anteriores se conservan en [el documento previo](historia/E3-ENTREGA3-preauditoria.md); aquí se precisan según lo efectivamente versionado.

| Prueba | Evidencia original | Alcance comprobable al leerla |
|---|---|---|
| Balanceo inicial | [balanceo-roundrobin.txt](../evidencias/e3/balanceo-roundrobin.txt) | 8 respuestas 200, 4 web1 / 4 web2 |
| Falla web2 | [failover-web2-detenido.txt](../evidencias/e3/failover-web2-detenido.txt) | 8 respuestas 200 de web1; el archivo no incluye comando de parada ni log DOWN |
| Recuperación web2 | [recuperacion-web2.txt](../evidencias/e3/recuperacion-web2.txt) | 8 respuestas 200, 4/4; falta log UP y medición de tiempo |
| HTTPS | [https-haproxy.txt](../evidencias/e3/https-haproxy.txt) | 6 respuestas HTTP/2 200, 3/3; no demuestra confianza ni SAN |
| Carrito después de migrar DB | [carrito-coherencia-postmigracion.txt](../evidencias/e3/carrito-coherencia-postmigracion.txt) | Producto 43 añadido en web1, leído y retirado en web2; resultado textual exitoso |
| Firewall DB tras reinicio | [firewall-db-tras-reinicio.txt](../evidencias/e3/firewall-db-tras-reinicio.txt) | TCP desde ambos web permitido, desde proxy no conecta; no contiene reglas/contadores completos |
| Backup vía systemd | [backup-mariadb-systemd.txt](../evidencias/e3/backup-mariadb-systemd.txt) | Servicio de **staging anterior** exitoso, 52 tablas; no acredita timer productivo ni réplica remota |
| Restauración aislada | [restauracion-mariadb-docker.txt](../evidencias/e3/restauracion-mariadb-docker.txt) | `network none`, sin puertos, 52 tablas, 51 posts, 512 opciones, 4 usuarios |

El usuario/equipo confirmó adicionalmente **balanceo 5/5**, continuidad, reglas DOCKER-USER, bloqueo DB→HTTPS del proxy y copia remota `nodo_sur_final-20261020-190237.sql.gz` en `archive` de VM268 con SHA-256/GZIP correctos y 52 tablas. Se conserva como **resultado reportado**, pendiente de salida saneada que permita auditarlo independientemente. Los dos archivos de carrito tienen contenido idéntico; sus commits indican etapas distintas, pero el texto por sí solo no distingue las ejecuciones.

## Correcciones de esta rama

Se corrigieron dependencias de firewall web inexistentes, rutas de ejecución root desde homes, colisión de staging/productivo, creación accidental de mounts vacíos, secreto web2 sin enlace `_FILE`, DNS de ejemplo apuntando a web1 y validadores que no propagaban errores. Se añadieron prechequeo NFS, publicación de respaldos con lock/checksum, verificador de copias, servicio/timer base de respaldo, reglas de firewall por destino original y restricciones Apache en uploads. Estas correcciones **no están desplegadas**; el detalle y sus riesgos están en [auditoría](AUDITORIA-E3.md).

## Procedimientos y cumplimiento

- [Instalación](INSTALACION-E3.md): dependencias, archivos privados, roles, orden de arranque y adopción sin perder el volumen DB.
- [Operación](OPERACION-E3.md): comprobaciones, failover, recuperación de backend, carrito y diagnóstico.
- [Recuperación](RECUPERACION-E3.md): respaldo íntegro, restauración aislada, coordinación DB/uploads y rollback.
- [Matriz E3](MATRIZ-E3.md): evidencia por área y pendientes; falta rúbrica oficial para certificar criterios/puntajes.
- [Verificación local](../evidencias/e3/auditoria-local.txt): salida generada por esta auditoría, separada de las evidencias de VMs.

## Evaluación técnica

La evidencia apoya distribución del tráfico, continuidad ante caída de un web, estado compartido del carrito y recuperación aislada de DB. La arquitectura **no ofrece alta disponibilidad integral**: un único proxy, MariaDB, DNS y NFS siguen siendo SPOF; VM268 concentra tres funciones críticas. No hay RPO/RTO medidos, copia fuera del laboratorio acreditada, restauración completa de uploads/configuración, ni supervisión centralizada demostrada.

E3 es defendible como implementación distribuida con tolerancia al fallo de un backend y evidencia funcional acotada. El cierre requiere capturar configuración/evidencia faltante, validar las correcciones en laboratorio y contrastar la rúbrica oficial; no es justificable declararlo íntegramente reproducible o totalmente conforme todavía.
