# Inventario de infraestructura — cierre E1–E4 y preparación E5

Direcciones IPv4 y hostnames verificados mediante SSH el 26/11/2026; sincronización horaria observada el 23/11/2026. Las definiciones y commits de octubre se conservan como antecedentes históricos. Las IPs `10.33.195.x` son de acceso/administración; el tráfico entre componentes se realiza principalmente por `10.33.199.56/29`.

| VMID | Hostname observado | Rol | SSH/administración | IP interna | Imagen/servicio |
|---|---|---|---|---|---|
| 268 | `vm268-dns-nfs` | DNS BIND9, NFS, copias de respaldo | `10.33.195.218` | `10.33.199.59` | BIND9 y NFS del host |
| 263 | `vm263-web1` | WordPress web1 | `10.33.195.183` | `10.33.199.58` | `nodosur-web1`, `wordpress:7.1.2-php8.3-apache` |
| 310 | `vm310-web2` | WordPress web2 | `10.33.195.197` | `10.33.199.62` | `nodosur-web2`, `wordpress:7.1.2-php8.3-apache` |
| 279 | `vm279-mariadb` | MariaDB y backups locales | `10.33.195.226` | `10.33.199.60` | `nodosur-db-staging`, `mariadb:10.11` |
| 308 | `vm308-proxy-monitor` | HAProxy, entrada HTTPS y observabilidad | `10.33.195.194` | `10.33.199.61` | `nodosur-haproxy`, `haproxy:3.2.23-alpine` |

## Estandarización de hostnames (26/11/2026)

| VM | Nombre anterior (alias local) | Hostname actual | Usuario SSH utilizado |
|---|---|---|---|
| 263 | `nodosurtas07` | `vm263-web1` | `tas_revision_e3` |
| 268 | `nodosur-g7` | `vm268-dns-nfs` | `tas_revision_e3` |
| 279 | `svr-db-nodosur07` | `vm279-mariadb` | `tas_revision_e3` |
| 308 | `nodosur-g7-proxy` | `vm308-proxy-monitor` | `nodosur-g7-proxy` |
| 310 | `nodosur-g7-web2` | `vm310-web2` | `tas_revision_e3` |

Se respaldaron `/etc/hostname` y `/etc/hosts` de cada VM en un directorio `/root/nodosur-hostname-*` con permisos 700; se cambió el hostname estático y la entrada local 127.0.1.1, conservando el nombre anterior como alias. Cloud-init reportó disabled en las cinco VM. No se cambiaron cuentas, rutas de systemd, contenedores ni direcciones; no se reiniciaron servicios ni VM.

Validaciones posteriores: BIND9 autoritativo NOERROR para `nodosur07.tas` → 10.33.195.194; NFS activo, exportaciones y montajes conservados; MariaDB original y copia de evaluación healthy; ambos backends HTTP 200 en logs del proxy; 12/12 targets UP, 4/4 sondas exitosas, `mysql_up=1`, cinco `nodename` nuevos, Grafana `database=ok`, cero alertas activas en Prometheus. Desde Fedora, DNS y resolución del cliente correctos, producto 45 y login Grafana HTTP 200 tras seguir redirecciones con `curl -k -L` (sin acreditar confianza TLS). Temporizadores de respaldo conservados. Persistencia tras reinicio y ejecución posterior de respaldos pendientes; no se repitió incidente ni restauración.

## Comprobaciones históricas de E3 (20–21/10)

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

## Corte de noviembre y datos aún no capturados

- E42 (23/11): las cinco VM reportaron `Timezone=Etc/UTC`, `NTP=yes` y `NTPSynchronized=yes`. No se midió el desfase de reloj.
- E43 (23/11): VM308 y VM310 declararon DHCP en ens18 y dirección interna fija en ens19. Las IP administrativas no están garantizadas tras reinicio.
- A18 (18/11): cinco VM con 2 vCPU, aproximadamente 1,9 GiB de RAM y raíz de 97G según `df -h`. No es una prueba de capacidad bajo carga.
- VM308 aloja Prometheus, Grafana, Alertmanager, Mailpit y exporters; consultar [estado E4](docs/ENTREGA4.md).
- **Versiones efectivas verificadas el 21/10**: WordPress web1 **7.1.3** y web2 **7.1.3** tras actualización controlada de web2. Los cuatro árboles auditados (`wp-admin`, `wp-includes`, plugins y temas; **9.817 archivos**) tienen huellas SHA-256 idénticas entre ambas webs, igual que los archivos principales seleccionados de la raíz salvo `wp-config.php` ([comparación](evidencias/e3/comparacion-post-upgrade-web1-web2-20261021.txt), [raíz](evidencias/e3/wordpress-raiz-sha256-igual-web1-web2-20261021.txt)). WooCommerce 11.1.0 coincidía según auditoría anterior. Todavía falta verificar configuración dinámica, activaciones y equivalencia de sesiones; digests de imágenes Docker no capturados. Los Compose conservan el tag declarado `wordpress:7.1.2-php8.3-apache`, distinto de la versión efectiva persistida.
- Versiones/configuración real de BIND9, exports NFS, ACL de todos los hosts y permisos de secretos; solo parte está contrastada.
- Evidencia de reinicios completos y persistencia de todas las políticas después del arranque.

Los valores de plantilla y los recursos de E2 no se presentan como inventario confirmado de E3.
