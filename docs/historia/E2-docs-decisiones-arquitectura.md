# Decisiones de arquitectura

## 1. Separar DNS, Web y DB

La entrega actual utiliza tres VMs con roles diferenciados:

- `.59`: DNS autoritativo.
- `.58`: Apache + PHP-FPM + WordPress/WooCommerce.
- `.60`: MariaDB.

La separación evita concentrar toda la plataforma en una única VM y permite administrar cada servicio según su exposición y dependencia.

## 2. Base de datos por red interna

WordPress utiliza `db.nodosur07.tas`, que resuelve a `10.33.199.60`. MariaDB escucha en la interfaz interna y UFW restringe 3306 a hosts explícitos de la red del Grupo 7.

Esto separa:

- IP administrativa/SSH de `.60`: `10.33.195.226`.
- IP de servicio MariaDB: `10.33.199.60`.

## 3. DNS autoritativo sin recursión

BIND9 administra `nodosur07.tas` como zona autoritativa y tiene `recursion no;`. El objetivo es responder por los nombres del proyecto, no operar como resolver general de Internet.

## 4. FQDN estable y cutover por DNS

El servicio web se movió a `.58` sin cambiar el nombre utilizado por los clientes. El registro A del apex y `www` pasó a `10.33.195.202` mientras `ns1` permaneció en `.59`.

Esto demuestra que identidad de servicio (FQDN) y host físico/virtual no son lo mismo.

## 5. HTTPS autofirmado

Para el laboratorio se utiliza certificado TLS autofirmado con SAN para `nodosur07.tas` y `www.nodosur07.tas`.

El tráfico queda cifrado, pero los navegadores no confían públicamente en la CA del certificado; por eso puede aparecer advertencia de confianza. No se declara como certificado público.

## 6. PHP-FPM con MPM event

La VM web utiliza Apache con PHP-FPM en lugar de mantener PHP embebido con `mod_php`. La configuración fue validada con la aplicación y tienda respondiendo HTTP 200.

## 7. Almacenamiento dedicado para uploads

`wp-content/uploads` usa un LV LVM de 20 GiB montado persistentemente por UUID. Los uploads son datos mutables y esta separación facilita administración, respaldo y una futura migración a almacenamiento compartido.

## 8. Acceso administrativo nominativo y mínimo privilegio

Los integrantes usan cuentas individuales y pertenecen a `ssh-nodosur`. `PermitRootLogin no` evita acceso SSH directo como root y UFW limita el origen del tráfico administrativo a VPN/laboratorio.

Las cuentas operativas (`cduran`, `nmatamala`, `jsaez`, `jdiaz`) pertenecen a `nodosur-ops` y `systemd-journal`, pero no al grupo `sudo`. Cada VM autoriza únicamente los comandos necesarios para operar el servicio correspondiente mediante reglas específicas de sudo:

- `.58 WEB`: operaciones controladas sobre Apache, PHP-FPM y consulta de UFW.
- `.59 DNS`: operaciones controladas sobre BIND/rndc, validación de zona y consulta de UFW.
- `.60 DB`: gestión del servicio MariaDB, comprobación mediante script fijo propiedad de root y consulta de UFW.

Cada VM conserva una cuenta bootstrap/recovery con sudo completo para contingencias. La cuenta `tas_revision` dispone temporalmente de sudo completo exclusivamente para revisión docente y debe revocarse al finalizar la evaluación.

## 9. SPOF declarados

La entrega actual no afirma alta disponibilidad completa. Persisten SPOF por rol:

- un solo DNS;
- un solo backend web;
- una sola DB.

HAProxy, segundo backend, NFS compartido y monitoreo centralizado son evolución posterior y deben presentarse como arquitectura objetivo, no como componentes ya implementados.
