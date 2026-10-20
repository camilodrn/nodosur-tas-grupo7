# Prueba reproducible — SSH, firewall y sudo limitado

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Comprobar que el acceso administrativo es nominativo, que root no entra directamente por SSH, que UFW restringe el puerto 22 a VPN/laboratorio y que las cuentas operativas del equipo usan sudo limitado por rol.

## Configuración SSH efectiva

La comprobación completa de `sshd -t/-T` requiere `tas_revision` o la cuenta bootstrap/recovery de la VM, porque esos comandos no forman parte del sudo limitado de las cuentas operativas:

```bash
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | grep -E \
'permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|allowgroups'
```

Estado esperado:

```text
permitrootlogin no
pubkeyauthentication yes
passwordauthentication yes
kbdinteractiveauthentication no
allowgroups ssh-nodosur
```

## Identidades y grupos

Estas consultas no requieren sudo:

```bash
getent group ssh-nodosur
getent group nodosur-ops
getent group systemd-journal
getent group sudo
```

Cuentas nominativas del equipo:

- `cduran`
- `nmatamala`
- `jsaez`
- `jdiaz`

Las cuatro cuentas operativas pertenecen a `ssh-nodosur`, `nodosur-ops` y `systemd-journal`, pero no al grupo `sudo`.

Cada VM mantiene una cuenta bootstrap/recovery con sudo completo:

- `.58`: `tas_07`
- `.59`: `nodosur-g7`
- `.60`: `svr-db-nodosur07`

La cuenta `tas_revision` es temporal para revisión docente, pertenece a `sudo` y conserva acceso administrativo completo durante la evaluación. Sus credenciales no se almacenan en el repositorio.

## Sudo limitado por rol

Comprobar en una sesión nueva de una cuenta operativa:

```bash
id
sudo -l
```

### VM .58 WEB

Debe permitir únicamente operaciones definidas para Apache, PHP-FPM y consulta de UFW, por ejemplo:

```bash
sudo /usr/sbin/apache2ctl configtest
journalctl -u apache2 -n 5 --no-pager
sudo /bin/bash
```

Resultados validados:

- `apache2ctl configtest` → `Syntax OK`.
- lectura de logs mediante `systemd-journal` → permitida sin sudo.
- `sudo /bin/bash` → rechazado.

### VM .59 DNS

Pruebas validadas:

```bash
sudo /usr/bin/named-checkconf
sudo /usr/bin/named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
sudo /usr/sbin/rndc status | head
journalctl -u named -n 5 --no-pager
sudo /bin/bash
```

Resultados:

- configuración BIND válida.
- zona `nodosur07.tas` cargada con `OK`.
- `rndc status` permitido.
- logs visibles sin sudo.
- shell root arbitrario rechazado.

### VM .60 DB

La administración operativa no expone `sudo mariadb` directamente. Se usa un script fijo propiedad de root para comprobar servicio, listener, versión y presencia de la base `nodo_sur_final`.

```bash
sudo /usr/local/sbin/nodosur-db-check
journalctl -u mariadb -n 5 --no-pager
sudo /bin/bash
sudo /usr/bin/mariadb
```

Resultados validados:

- MariaDB `active`.
- listener `10.33.199.60:3306`.
- versión `10.11.14-MariaDB-0ubuntu0.24.04.1`.
- base `nodo_sur_final` presente.
- `sudo /bin/bash` rechazado.
- `sudo /usr/bin/mariadb` rechazado para las cuentas operativas.

## Cuenta temporal de revisión docente

En las tres VMs, una sesión nueva de `tas_revision` debe mostrar pertenencia a `sudo` y permitir:

```bash
id
sudo whoami
```

Resultado validado: `sudo whoami` devuelve `root` en `.58`, `.59` y `.60`.

En `.60`, la cuenta de revisión también fue validada con:

```bash
sudo mariadb
```

y se comprobó el pedido WooCommerce `#71` dentro de `nodo_sur_final`.

## Firewall

La consulta de UFW está incluida en las políticas de sudo de `nodosur-ops`:

```bash
sudo /usr/sbin/ufw status numbered
```

El puerto 22 debe estar permitido desde:

- VPN `10.30.248.0/24`.
- Laboratorio `10.33.21.0/24`.

No debe existir una regla `OpenSSH Anywhere`.

## Evidencia de AllowGroups

Durante la implementación en `.59`, `cduran` fue rechazado cuando aún no pertenecía a `ssh-nodosur`. El journal registró:

```text
User cduran ... not allowed because none of user's groups are listed in AllowGroups
```

Después de agregarlo al grupo, el acceso quedó registrado como aceptado. Esto demuestra que `AllowGroups` participa realmente en la autorización del acceso.
