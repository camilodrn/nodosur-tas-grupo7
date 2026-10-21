# Decisiones de arquitectura — Entrega 3

Estas decisiones describen la plataforma **implementada**, no la configuración experimental de la auditoría. La [versión anterior del documento](https://github.com/camilodrn/nodosur-tas-grupo7/blob/279466d/docs/decisiones-arquitectura.md) corresponde a la etapa E2: tres VMs, Apache/PHP-FPM nativo y uploads locales.

| Decisión E3 | Por qué se eligió | Ventaja | Límite / riesgo |
|---|---|---|---|
| Mantener BIND9 en VM268 | Conservar un FQDN de servicio estable y separar resolución de publicación | `nodosur07.tas` apunta al proxy, no directamente a web1 | Un único DNS; depende de VM268 |
| Dos WordPress en Docker, en VM263 y VM310 | Evitar que falle toda la experiencia principal al caer un web | Tráfico repartido, contenedores equivalentes en imagen declarada | Los archivos locales del CMS/plugins deben mantenerse consistentes |
| HAProxy independiente en VM308 | Centralizar entrada HTTPS y detectar backends fallidos | `roundrobin`, `HEAD /`, `X-NodoSur-Backend` y continuidad ante fallo de web2 | El propio proxy es un SPOF; no asegura RTO fijo |
| TLS en HAProxy con certificado autofirmado | Implementación adecuada para laboratorio sin CA pública | HTTPS y redirección; SAN apex y `www` comprobados | El cliente debe confiar explícitamente en el certificado |
| Una sola MariaDB en VM279 | Evitar estados de negocio divergentes entre dos webs | Un único origen de datos para WordPress y WooCommerce | MariaDB es SPOF |
| Preservar volumen histórico `nodosur-db-staging_db_stage_data` | No perder datos al pasar la base al entorno Docker | Mantiene datos existentes, aunque el nombre sea engañoso | Un Compose con otro nombre de proyecto/volumen podría crear datos vacíos |
| NFS en VM268 **solo para uploads** | Las imágenes subidas deben estar disponibles desde ambos web | Se comprobó SHA-256 idéntico desde NFS, web1 y web2 | NFS SPOF; no sincroniza plugins, temas ni configuración |
| Filtrar puertos Docker mediante `DOCKER-USER` | Evitar que clientes accedan directamente a los puertos internos web | En ambos hosts web hay DROP de fuentes distintas del proxy `.61` | Debe verificarse junto con otras cadenas/ACL y después de reinicios |
| Manejar los contenedores por Compose + systemd | Separar servicio por rol y arranque controlado | Cada VM gestiona su propio componente | Un `active (exited)` de systemd no prueba contenedor vivo |
| Custodiar secretos fuera de Git | No publicar claves, passwords, salts ni PEM privados | Repositorio compartible para evaluación | La reproducción necesita los archivos privados y permisos correctos |

## Cambios adoptados y aún pendientes

La propuesta de **bloquear ejecución PHP dentro de `uploads`** se adaptó, probó en Apache aislado y **desplegó en web1 y web2** el 21/10/2026 mediante Compose, con respaldo previo y comprobación de portada, tienda, imagen NFS y HTTP 403. [Evidencia final](../evidencias/e3/apache-uploads-web1-web2-final-20261021.txt).

Otras ideas de Codex —mover scripts y Compose a `/opt/nodosur`, reconstruir cadenas de firewall, endurecer encabezados HAProxy, cambiar cómo se referencia el secreto de web2 y reformar backup/staging— continúan en evaluación separada. **No deben describirse como cambios ejecutados en producción**.

[Detalle de la revisión de Codex](REVISION-CODEX-E3.md).

## Riesgos reconocidos

Se comprobó distribución 4/4, continuidad con web2 ausente (ocho HTTP 200), recuperación de reparto, carrito compartido, y lectura idéntica de un upload en ambos web. Eso **no** demuestra recuperación automática de todos los contenedores ni tolerancia a fallas de proxy, base de datos, DNS o NFS. No se midieron RTO/RPO ni se demostró restauración funcional integrada de los respaldos.
