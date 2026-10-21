# Despliegue y reconstrucción controlada — Nodo Sur E3

**Objetivo:** que otra persona comprenda y pueda repetir la puesta en marcha de los componentes, distinguiendo el **código versionado** de los **datos/secretos/infraestructura externos**. Esta guía documenta la implementación real; **no afirma** haber reconstruido exitosamente las cinco VMs desde cero.

> **Seguridad:** ningún comando de esta guía debe ejecutarse a ciegas en las VMs productivas. Antes de intervenirlas, confirmar respaldo, ventana y acceso de recuperación. No usar `docker compose down -v`, `docker volume prune`, `git reset --hard` ni sobrescribir `wp-config.php`/certificados/BD. No enviar secretos a GitHub ni al chat.

## Arquitectura y orden de dependencias

El laboratorio se implementa **por host**, con cuatro proyectos Compose independientes y BIND9/NFS nativos en VM268. **No es un único Compose multiservidor ni un clúster Docker Swarm/Kubernetes.** El flujo lógico es:

1. **VM268 — DNS/NFS:** zona `nodosur07.tas`, exports de uploads y resolución hacia el proxy.
2. **VM279 — MariaDB:** base común `nodo_sur_final` y volumen persistente histórico.
3. **VM263/VM310 — WordPress:** aplicación ya aprovisionada en bind mounts locales y uploads montados por NFS; conexión a la misma BD.
4. **VM308 — HAProxy:** entrada HTTP/HTTPS, certificado autofirmado, `roundrobin`, `HEAD /` como health check y backends anteriores.

Este orden representa las dependencias para un **arranque planificado**, no autoriza detener ni reiniciar componentes que actualmente funcionan.

| VM | Acceso SSH administrativo | IP interna | Compose / componente |
|---|---|---|---|
| 268 | `10.33.195.205` | `10.33.199.59` | BIND9 y NFSv4.1 del host |
| 279 | `10.33.195.226` | `10.33.199.60` | `compose/db-stage/compose.prod.yaml` |
| 263 | `10.33.195.202` | `10.33.199.58` | `compose/web1/compose.yaml` |
| 310 | `10.33.195.208` | `10.33.199.62` | `compose/web2/compose.yaml` |
| 308 | `10.33.195.194` | `10.33.199.61` | `compose/proxy/compose.prod.yaml` |

Red interna: `10.33.199.56/29` (hosts utilizables `.57`–`.62`). Puertos: 53 UDP/TCP DNS, 2049 TCP NFS, 3306 TCP MariaDB, 18081/18080 TCP backends, 80/443 TCP proxy. Acceso externo al laboratorio mediante red/VPN autorizada.

## Fuente de configuración y datos fuera de Git

| Rol | Entrada que versiona Git | Requisito externo que NO se puede reconstruir con `git clone` |
|---|---|---|
| DNS/NFS | Documentación de arquitectura y configuraciones históricas verificables por separado | VMs/redes, zona BIND vigente, claves y permisos si las hay, `/srv/nodosur/uploads` en VM268, export NFS autorizado, directorio de respaldos |
| MariaDB | `compose/db-stage/compose.prod.yaml`: `mariadb:10.11`, puerto `.60:3306`, `MARIADB_ROOT_PASSWORD_FILE`, health check | `/etc/nodosur/secrets/db-stage-root.password` no vacío, permisos adecuados, volumen real `nodosur-db-staging_db_stage_data` con sus datos; credenciales de acceso de los WordPress |
| Web1 | `compose/web1/compose.yaml`: `wordpress:7.1.2-php8.3-apache`, bind HTML/NFS/Apache | `/srv/nodosur/web1/html` con WordPress y `wp-config.php` propio, NFS montado en `/srv/nodosur/nfs/uploads`, archivo Apache instalado en `/etc/nodosur/apache/nodosur-uploads.conf`, acceso DB y firewall de host |
| Web2 | `compose/web2/compose.yaml`: imagen, variables no secretas, bind HTML/NFS/Apache, secreto | `/srv/nodosur/web2/html` con WordPress y `wp-config.php`, secreto `/etc/nodosur/secrets/cms_web62.password`, NFS, Apache y firewall de host |
| Proxy | `compose/proxy/compose.prod.yaml`, `compose/proxy/haproxy.prod.cfg` | Certificado **con clave privada** en `/etc/nodosur/tls/haproxy-www.pem` (NO versionar), DNS/red y backends funcionales |

**Atención:** `compose/db-stage/compose.prod.yaml` sigue utilizando el proyecto llamado `nodosur-db-staging`. El volumen en uso es **`nodosur-db-staging_db_stage_data`** aunque la plataforma atiende E3. No cambiar nombre de proyecto/volumen ni activar un Compose alternativo: se corre el riesgo de que se cree un volumen vacío y parezca que se perdieron los datos.

Los `wp-config.php` reales y las configuraciones WordPress montadas son datos locales. **La imagen `wordpress:7.1.2-php8.3-apache` no los reemplaza automáticamente.** La [documentación oficial de la imagen](https://hub.docker.com/_/wordpress) señala que el WordPress inicial queda persistido en `/var/www/html` y puede actualizarse automáticamente por su cuenta. En este laboratorio se detectó inicialmente **web1 WordPress 7.1.3 y web2 7.1.2**, aunque los dos Compose declaraban la misma imagen. El **21/10/2026 se alineó web2 a 7.1.3** con respaldo y parada controlada y se demostró la recuperación vía HAProxy ([plan y evidencia](PLAN-ALINEACION-WORDPRESS-E3.md)); el esquema declarado quedó `61833` en ambos. Coinciden SHA-256 de los cuatro árboles centrales de código y de los principales archivos de raíz ([evidencia](../evidencias/e3/comparacion-post-upgrade-web1-web2-20261021.txt), [raíz](../evidencias/e3/wordpress-raiz-sha256-igual-web1-web2-20261021.txt)). **No se ha comprobado qué originó el desfase inicial.** Los plugins/temas, salts y configuración efectiva deben mantenerse coherentes entre ambas webs; NFS cubre **solo `uploads`**. La etiqueta Docker persistió en `wordpress:7.1.2-php8.3-apache` aunque el núcleo instalado sea 7.1.3.

Las unidades systemd reales referencian `/home/USUARIO/nodosur-tas-grupo7`; **no** se migraron a `/opt/nodosur`. El servicio `nodosur-docker-firewall.service` protege puertos internos de web1 y web2 usando `DOCKER-USER`. La declaración Compose **no crea por sí sola** todas las políticas de red/systemd.

## Preparación de un nuevo host: inventario, sin ejecutar en producción

**Antes de cualquier despliegue** hay que realizar, en una VM nueva o restaurada bajo autorización:

1. Preparar IP, ruta, VPN, cuenta SSH y acceso administrativo. Confirmar DNS y transporte NFS donde corresponda.
2. Instalar Docker Engine y Compose plugin en las cuatro VMs Docker; BIND9 y servidor NFS donde corresponda. Registrar las versiones efectivamente usadas.
3. Clonar una **revisión aprobada** de este repositorio en el `HOME` de cada cuenta operadora. La rama `e3/cierre-tecnico` aún es un PR; evitar mezclar checkouts y no reemplazar configuraciones existentes.
4. Provisionar **por canal privado** los archivos y permisos exigidos por la tabla anterior; restaurar el WordPress/BD/archivos de una fuente autorizada. Nunca publicar esas copias.
5. Confirmar que NFS esté montado y que los bind mounts HTML de WordPress existan **antes** de crear contenedores. En web2 un bind HTML histórico usa sintaxis abreviada que podría crear directorio vacío si falta; comprobar explícitamente su existencia.
6. Validar cada Compose con `docker compose -f RUTA config --quiet` y revisar `docker compose -f RUTA config --format json` **sin imprimir variables de entorno con secretos**.
7. Comprobar la política de firewall de host, permisos, servicio systemd efectivo y arranque controlado. Hacerlo rol por rol, tras respaldo y plan de reversión.
8. Verificar aplicación y almacenamiento **antes de publicar el proxy**: salud MariaDB, WordPress por backend, imagen NFS con SHA-256, DNS, HAProxy `haproxy -c`, TLS, balanceo y rechazo de PHP en uploads.

Estos pasos describen los requisitos. **No existe evidencia de una instalación limpia automatizada ni una prueba end-to-end de restauración integrada.** No prometer “reconstrucción sin ajustes manuales” ante el docente.

## Validaciones de solo lectura en el entorno existente

Desde la VM de cada rol, bajo su propia cuenta autorizada:

```bash
# Inspección inicial; no cambia Docker
git status --short
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

# Por rol: ajustar archivo ANTES de ejecutar
sudo docker compose -f compose/web1/compose.yaml config --quiet
sudo docker compose -f compose/web2/compose.yaml config --quiet
sudo docker compose -f compose/db-stage/compose.prod.yaml config --quiet
sudo docker compose -f compose/proxy/compose.prod.yaml config --quiet

# En web1 o web2: NFS montado
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,OPTIONS

# En web1 o web2: comprobar solo PRESENCIA del archivo Apache,
# sin editarlo ni imprimir otro material sensible.
sudo test -s /etc/nodosur/apache/nodosur-uploads.conf && echo 'APACHE CONFIG: PRESENTE'
```

**Los cuatro comandos Compose se ejecutan en sus respectivas VMs**, no los cuatro juntos en cada VM. Los `config --quiet` comprueban sintaxis y resolución de estructura; no garantizan que secretos, servicios, volúmenes ni puertos estén operativos.

Herramientas de consulta incluidas en la rama: `bash scripts/preflight-e3.sh ROL` (en cada VM del rol; verifica contenedor, ruta/mount y configuración) y `NODOSUR_REPO_DIR=RUTA bash scripts/compose-fingerprint-e3.sh ROL` (en Fedora y VM; solo imprime una huella del Compose JSON normalizado). **Las huellas solo son comparables si se usa el mismo rol y configuración efectiva**, y no comprueban que un contenedor haya sido creado con esa definición. **Comprobación ejecutada:** [las huellas de web1 y web2 coincidieron exactamente](../evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt) entre el clon Fedora y ambas VMs; permanecen modificaciones locales sin reconciliar. Los scripts deben estar presentes y pasar revisión de sintaxis antes de ejecutarse.

Para capturar comprobaciones con alcance más preciso: [evidencia de Apache en producción](../evidencias/e3/apache-uploads-web1-web2-final-20261021.txt), [matriz de flujos](MATRIZ-FLUJOS-E3.md), [validaciones de E3](ENTREGA3.md) y [rúbrica](RUBRICA-E3.md).

**Preflight DB y proxy verificado el 21/10/2026:** se ejecutaron `docker compose ... config --quiet` correctamente en VM279 y VM308, y se comprobaron contenedores en ejecución, imagen, DB `healthy`, volumen histórico y existencia de archivos privados ([evidencia](../evidencias/e3/preflight-db-proxy-compose-20261021.txt)). Los repos locales aparecieron limpios, pero no se comprobó igualdad de commit/branch con `e3/cierre-tecnico`. Estas validaciones no sustituyen reconstrucción limpia de la infraestructura.

## Persistencia y recuperación

La BD está en un **volumen Docker productivo** en VM279. El WordPress local está en bind mounts separados por backend. `uploads` está compartido por NFS y depende de VM268. Por eso un respaldo íntegro necesita **consistencia coordinada de base de datos, WordPress local y NFS**, además de secretos y configuraciones: copiar solo `uploads` no restaura la tienda completa.

La documentación actual no acredita todavía una restauración integral de esas piezas desde cero ni un RTO/RPO observado. Esto constituye una **brecha de reproducibilidad** explícita, no un defecto que deba esconderse.

## Precauciones para actualización Git

En VM263 y VM310, la configuración Apache se introdujo directamente en sus Compose durante una intervención aprobada. La [auditoría Git de los dos backends](../evidencias/e3/git-backends-cambios-locales-20261021.txt) confirmó que **VM263 está en `e3/backend1` (`8b067ef`) y VM310 en `e3/backend2` (`667d7d9`)**, cada una con **un solo archivo localmente modificado**: su Compose, al que se añadieron ocho líneas para montar `nodosur-uploads.conf` de solo lectura y sin crear rutas faltantes. `git diff --check` no reportó errores. Ya se había comprobado que las [huellas semánticas de Compose](../evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt) coincidían con las de Fedora. La rama del PR no es la rama instalada en las VMs.

**Decisión para E3:** preservar los cambios locales ya operativos; no es necesario dejar los checkouts Git limpios para demostrar el Compose vigente y no se requiere reiniciar ni recrear servicios. No ejecutar `reset --hard`, `clean`, `stash -u` ni `pull` indiscriminadamente. Si posteriormente se requiere alinear ramas, hacerlo con revisión de diff, respaldo, reversión y ventana de intervención. El estado Git limpio y la igualdad de hashes de Compose son criterios diferentes.

## Tabla de aceptación para reconstrucción futura

| Condición observable | Criterio de aceptación |
|---|---|
| DNS | Registros apex/www hacia HAProxy y resolución autoritativa UDP/TCP correctos |
| MariaDB | `nodosur-db-staging` running/healthy con volumen **exactamente** `nodosur-db-staging_db_stage_data` |
| WordPress | Dos nodos independientes, portada/tienda/imagen HTTP 200 |
| Almacenamiento | Hash de un mismo archivo NFS idéntico visto desde VM268, web1 y web2 |
| Seguridad | `DOCKER-USER` esperado en ambos backends, secretos solo por canal privado, PHP en uploads rechazado, Apache Syntax OK |
| HAProxy/TLS | `haproxy -c` válido; HTTP 301; HTTPS 200 con certificado autofirmado; ambos backends en rotación |
| Fallo controlado | Con autorización, un backend fuera, el otro responde, evento `DOWN` capturado, reintegro y evento `UP` capturados |
| Defensa | Identificar SPOF, límites de health check, resultados y pasos de reversión sin atribuir HA total |
