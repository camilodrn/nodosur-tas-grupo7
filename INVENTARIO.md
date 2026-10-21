# Inventario E3

| VM | Rol | Hostname registrado | Administración | Interna |
|---|---|---|---|---|
| 268 | BIND9, NFS, respaldos | `nodosur-g7` (E2; reconfirmar) | 10.33.195.205 | 10.33.199.59 |
| 263 | WordPress/WooCommerce web1 Docker | `nodosurtas07` (E2; reconfirmar) | 10.33.195.202 | 10.33.199.58 |
| 310 | WordPress/WooCommerce web2 Docker | No capturado | 10.33.195.208 | 10.33.199.62 |
| 279 | MariaDB Docker | `svr-db-nodosur07` (E2; reconfirmar) | 10.33.195.226 | 10.33.199.60 |
| 308 | HAProxy Docker | No capturado | 10.33.195.194 | 10.33.199.61 |

Red interna `10.33.199.56/29`, gateway observado `.57`; VPN `10.30.248.0/24`, laboratorio `10.33.21.0/24`. SSH administrativo por TCP 22, sujeto a ACL por origen. Reconfirmar interfaces; las evidencias DB muestran `ens19` como interna. Los scripts auditados no dependen del nombre de interfaz para filtrar puertos Docker.

Ubuntu Server 24.04 LTS y plantilla de 2 vCPU, 2 GiB RAM, disco 200 GiB se registraron en E2. **No hay captura de recursos/SO de las cinco VMs en E3**. No extrapolar capacidad ni versiones de paquetes.

| Imagen declarada | Uso | Estado de verificación |
|---|---|---|
| `wordpress:7.1.2-php8.3-apache` | ambos web | Tag heredado; no se verificó disponibilidad, digest ni versión del bind montado |
| `mariadb:10.11` | DB | Tag mutable; capturar digest instalado antes de fijarlo |
| `haproxy:3.2.23-alpine` | proxy | Tag heredado; no se descargó ni ejecutó en esta auditoría |

El nombre productivo `nodosur-db-staging` es histórico. Staging nuevo usa `nodosur-db-lab` en 13307 con volumen y secreto distintos. Proxy de laboratorio usa `nodosur-proxy-lab` y solo loopback 18088/18443. Ver [instalación](docs/INSTALACION-E3.md) antes de operar cualquiera de ellos.
