# Política sudo limitada por rol

Los archivos `web.sudoers.example`, `dns.sudoers.example` y `db.sudoers.example` conservan la política histórica E2 de tres VMs. No describen permisos Docker de E3.

Para E3, `db-e3.sudoers.example` propone únicamente la consulta fija `/usr/local/sbin/nodosur-db-check-e3` sin argumentos. Instalar el script y todos sus padres como root, sin escritura de cuentas operativas. Verificar con `visudo -cf` antes de instalar con modo 0440. Nunca autorizar el comando Docker completo ni añadir operadores al grupo `docker`: permite privilegios equivalentes a root. Las políticas de las cinco VMs requieren comprobación en producción.

## Principio

Las cuentas nominativas del equipo (`cduran`, `nmatamala`, `jsaez`, `jdiaz`) comparten el grupo `nodosur-ops` y no pertenecen al grupo `sudo`. Cada VM autoriza solo los comandos necesarios para operar su servicio principal.

Los integrantes también pertenecen a `systemd-journal` para consultar logs sin entregar root irrestricto.

## Cuentas de recuperación

Cada servidor conserva una cuenta bootstrap/recovery con sudo completo:

- `.58 WEB`: `tas_07`
- `.59 DNS`: `nodosur-g7`
- `.60 DB`: `svr-db-nodosur07`

Estas cuentas se reservan para contingencias y cambios excepcionales.

## Revisión docente

`tas_revision` es una cuenta temporal de evaluación con sudo completo en las tres VMs. Sus credenciales se entregan fuera de GitHub y deben revocarse al finalizar la evaluación.

## Archivos

- `web.sudoers.example`: operaciones Apache/PHP-FPM/UFW lectura.
- `dns.sudoers.example`: operaciones BIND/rndc/UFW lectura.
- `db.sudoers.example`: operaciones MariaDB de servicio, script de comprobación y UFW lectura.

Estos archivos no contienen contraseñas ni secretos.
