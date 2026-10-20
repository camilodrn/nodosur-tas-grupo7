# Inventario de infraestructura

| VM | Rol | Hostname | IP administración/lab | IP interna | Servicios principales |
|---|---|---|---|---|---|
| .58 | WEB/CMS | `nodosurtas07` | `10.33.195.202` | `10.33.199.58` | Apache, PHP-FPM, WordPress, WooCommerce |
| .59 | DNS | `nodosur-g7` | `10.33.195.205` | `10.33.199.59` | BIND9 autoritativo |
| .60 | DB | `svr-db-nodosur07` | `10.33.195.226` | `10.33.199.60` | MariaDB 10.11 |

## Sistema base

- Ubuntu Server 24.04 LTS.
- Plantilla de laboratorio con 2 vCPU, 2 GiB RAM y disco virtual de 200 GiB.

## Red interna

- Segmento: `10.33.199.56/29`
- Gateway observado: `10.33.199.57`
- Hosts usados por Nodo Sur: `.58`, `.59`, `.60`.

## Acceso administrativo

- SSH permitido desde VPN USM `10.30.248.0/24` y laboratorio `10.33.21.0/24`.
- Acceso SSH limitado a integrantes del grupo `ssh-nodosur`.
- Acceso directo de root por SSH deshabilitado.
