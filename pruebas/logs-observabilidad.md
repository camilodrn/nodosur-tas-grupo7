# Prueba reproducible — Logs y observabilidad

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Demostrar que los servicios críticos generan registros útiles y que es posible correlacionar un evento con su log sin ampliar innecesariamente los privilegios de las cuentas operativas.

## Apache HTTPS (.58)

Generar un evento identificable desde cliente:

```bash
curl -k -sS -o /dev/null -w 'HTTP %{http_code}\n' \
'https://nodosur07.tas/tienda/?evidencia=tas-20260908'
```

La correlación directa contra el access log se realiza con `tas_revision` o la cuenta bootstrap/recovery de `.58`:

```bash
sudo grep 'evidencia=tas-20260908' /var/log/apache2/nodosur_ssl_access.log
```

Resultado validado: HTTP 200 y registro de la petición desde la VPN.

Las cuentas operativas pueden consultar el journal de Apache mediante `systemd-journal`:

```bash
journalctl -u apache2 -n 20 --no-pager
```

## SSH

Las cuentas pertenecientes a `systemd-journal` pueden revisar eventos del servicio sin usar sudo arbitrario:

```bash
journalctl -u ssh -n 50 --no-pager
```

Los logs contienen accesos aceptados y rechazados, usuario, IP origen y apertura de sesión.

## BIND9 (.59)

El grupo `nodosur-ops` puede activar temporalmente el query logging mediante las reglas específicas de sudo:

```bash
sudo /usr/sbin/rndc querylog on
```

Desde cliente:

```bash
dig @10.33.195.205 db.nodosur07.tas A +short
```

Luego, en `.59`:

```bash
journalctl -u named --since '2 minutes ago' --no-pager
sudo /usr/sbin/rndc querylog off
```

Resultado validado: consulta A por `db.nodosur07.tas` registrada desde el cliente VPN.

## MariaDB (.60)

Desde `.58`, prueba negativa controlada:

```bash
mariadb -h db.nodosur07.tas -u evidencia_tas \
-p'NO_ES_UNA_PASSWORD_REAL' -e 'SELECT 1;'
```

En `.60`:

```bash
journalctl -u mariadb --since '2 minutes ago' --no-pager \
| grep -i 'Access denied'
```

Resultado validado: rechazo de `evidencia_tas` desde `10.33.199.58` registrado por MariaDB.

## Criterio

Las pruebas se diseñan para ser no destructivas y no exponer contraseñas reales. El query logging de DNS se desactiva tras la prueba para no generar ruido permanente. Cuando una comprobación requiere leer archivos de log protegidos directamente, se utiliza la cuenta temporal `tas_revision` o la cuenta bootstrap/recovery, no se amplía el sudo de los integrantes.
