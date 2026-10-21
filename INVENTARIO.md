# Inventario de infraestructura — Entrega 3

Actualizado según terminales observadas el 20–21/10/2026. Las IPs `10.33.195.x` son de acceso/administración; el tráfico entre componentes se realiza principalmente por `10.33.199.56/29`.

| VMID | Hostname observado | Rol | SSH/administración | IP interna | Imagen/servicio |
|---|---|---|---|---|---|
| 268 | `nodosur-g7` | DNS BIND9, NFS, copias de respaldo | `10.33.195.205` | `10.33.199.59` | BIND9 y NFS del host |
| 263 | `nodosurtas07` | WordPress web1 | `10.33.195.202` | `10.33.199.58` | `nodosur-web1`, `wordpress:7.1.2-php8.3-apache` |
| 310 | `nodosur-g7-web2` | WordPress web2 | `10.33.195.208` | `10.33.199.62` | `nodosur-web2`, `wordpress:7.1.2-php8.3-apache` |
| 279 | `svr-db-nodosur07` | MariaDB y backups locales | `10.33.195.226` | `10.33.199.60` | `nodosur-db-staging`, `mariadb:10.11` |
| 308 | `nodosur-g7-proxy` | HAProxy y entrada HTTPS | `10.33.195.194` | `10.33.199.61` | `nodosur-haproxy`, `haproxy:3.2.23-alpine` |

## Comprobaciones concretas

| VM | HEAD del checkout instalado | Definición Compose comprobada | Runtime |
|---|---|---|---|
| 263 | `8b067ef` | `compose/web1/compose.yaml` | Contenedor `running`; uploads bind `RW=true` |
| 310 | `667d7d9` | `compose/web2/compose.yaml` | Contenedor `running`; uploads bind `RW=true` |
| 279 | `488cb27` | `compose/db-stage/compose.prod.yaml` | Contenedor `running`; volumen `nodosur-db-staging_db_stage_data` |
| 308 | `fdaba39` | `compose/proxy/compose.prod.yaml` | Contenedor `running`; `haproxy -c` válido |

En las cuatro VMs se ejecutó exitosamente `docker compose -f ARCHIVO config --quiet` ([web1/web2](evidencias/e3/compose-productivo-web1-web2-y-php-20261021.txt) y [DB/proxy](evidencias/e3/compose-productivo-db-proxy-20261021.txt)). Los commits son diferentes por host; este inventario no presupone que los árboles completos sean idénticos.

**Rutas productivas observadas:**
- web1: `/srv/nodosur/web1/html` y `/srv/nodosur/nfs/uploads`.
- web2: `/srv/nodosur/web2/html` y `/srv/nodosur/nfs/uploads`.
- DB: volumen Docker `nodosur-db-staging_db_stage_data` montado en `/var/lib/mysql`.
- HAProxy: PEM privado fuera de Git, bajo `/etc/nodosur/tls/`.
- Código usado actualmente por unidades systemd: `/home/USUARIO/nodosur-tas-grupo7`, no `/opt/nodosur`.

**Red:** `10.33.199.56/29` (red `.56`, gateway registrado `.57`, hosts `.58` a `.62`, broadcast `.63`); VPN USM `10.30.248.0/24` y red de laboratorio `10.33.21.0/24`, sujetas a filtros por origen.

## Datos aún no capturados

- Salida de `hostnamectl` y recursos efectivos de CPU/RAM/almacenamiento para las cinco VMs.
- **Versiones efectivas parcialmente observadas**: WordPress web1 7.1.3 y web2 7.1.2; WooCommerce 11.1.0 y hash de su archivo principal iguales. La [comparación del árbol de archivos](evidencias/e3/wordpress-arboles-core-plugins-temas-20261021.txt) confirmó hashes iguales en plugins y temas y diferentes en directorios de core (`wp-admin` / `wp-includes`), con conteos iguales. Falta revisar activaciones/configuración de plugins y raíz del core; digests de imágenes Docker aún no capturados. [Evidencia](evidencias/e3/wordpress-equivalencia-web1-web2-20261021.txt).
- Versiones/configuración real de BIND9, exports NFS, ACL de todos los hosts y permisos de secretos; solo parte está contrastada.
- Evidencia de reinicios completos y persistencia de todas las políticas después del arranque.

Los valores de plantilla y los recursos de E2 no se presentan como inventario confirmado de E3.
