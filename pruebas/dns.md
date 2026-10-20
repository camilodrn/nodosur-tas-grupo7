# Prueba reproducible — DNS autoritativo

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Comprobar que BIND9 en `.59` responde por UDP/TCP 53 para la zona `nodosur07.tas` y entrega los registros usados por la arquitectura.

## Consultas directas

```bash
dig @10.33.195.205 nodosur07.tas A +short
dig @10.33.195.205 www.nodosur07.tas A +short
dig @10.33.195.205 db.nodosur07.tas A +short
dig @10.33.195.205 ns1.nodosur07.tas A +short
dig @10.33.195.205 nodosur07.tas A +tcp +short
```

Resultados esperados:

- `nodosur07.tas` → `10.33.195.202`
- `www.nodosur07.tas` → `10.33.195.202`
- `db.nodosur07.tas` → `10.33.199.60`
- `ns1.nodosur07.tas` → `10.33.195.205`
- La consulta TCP del apex también responde `10.33.195.202`.

## Validación de configuración en .59

Las cuentas operativas de `nodosur-ops` poseen permisos específicos para validar BIND:

```bash
sudo /usr/bin/named-checkconf
sudo /usr/bin/named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
systemctl is-active named
systemctl is-enabled named
```

`named-checkconf` sin salida indica sintaxis correcta; `named-checkzone` debe terminar en `OK`.

## Evidencia de consulta DNS

Logging temporal:

```bash
sudo /usr/sbin/rndc querylog on
sudo /usr/sbin/rndc status | grep -i query
```

Desde cliente:

```bash
dig @10.33.195.205 db.nodosur07.tas A +short
```

En `.59`, los integrantes pueden leer el journal mediante `systemd-journal`:

```bash
journalctl -u named --since '2 minutes ago' --no-pager
sudo /usr/sbin/rndc querylog off
```

Resultado validado el 08-09-2026: BIND registró una consulta A desde `10.30.248.3` por `db.nodosur07.tas` y respondió `10.33.199.60`.

> El query logging se apaga al finalizar para evitar registrar todas las consultas de forma permanente.
