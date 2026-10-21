# Prueba reproducible — Actualización de VMs

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Procedimiento aplicado

En cada VM se auditó primero la lista de paquetes:

```bash
sudo apt update
apt list --upgradable
apt list --upgradable 2>/dev/null | grep -E \
'apache|php|openssl|linux|systemd|openssh|mariadb|bind'
```

Después se aplicó:

```bash
sudo apt upgrade
```

No se utilizó `full-upgrade`.

> **Privilegios actuales:** el mantenimiento de paquetes no forma parte del sudo operativo limitado de `nodosur-ops`. Una actualización posterior debe realizarse mediante la cuenta bootstrap/recovery de la VM o, durante la evaluación, mediante `tas_revision`.

## Reboot requerido

```bash
if [ -f /var/run/reboot-required ]; then
  echo 'REBOOT REQUERIDO'
else
  echo 'NO REQUIERE REBOOT'
fi
```

Estado final validado el 08-09-2026: `.58`, `.59` y `.60` quedaron actualizadas y ninguna requirió reinicio.

## Validación post-mantenimiento

- `.58`: Apache/PHP-FPM activos, portada y tienda HTTP 200.
- `.59`: BIND activo y zona válida.
- `.60`: MariaDB activo y escuchando en la IP interna.

Desde cliente:

```bash
curl -k -sS -o /dev/null -w 'Inicio: HTTP %{http_code}\n' https://nodosur07.tas/
curl -k -sS -o /dev/null -w 'Tienda: HTTP %{http_code}\n' https://nodosur07.tas/tienda/
```

Resultados validados: `Inicio: HTTP 200` y `Tienda: HTTP 200`.
