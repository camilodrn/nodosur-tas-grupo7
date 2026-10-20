# Prueba reproducible — Web y HTTPS

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Comprobar resolución, redirección HTTP→HTTPS, respuesta de la aplicación y trazabilidad en logs.

## Desde cliente VPN/laboratorio

```bash
curl -I --connect-timeout 5 http://nodosur07.tas/
curl -kI --connect-timeout 5 https://nodosur07.tas/
curl -kI --connect-timeout 5 https://nodosur07.tas/tienda/
```

Resultados esperados:

- HTTP devuelve redirección permanente hacia HTTPS.
- HTTPS `/` responde HTTP 200.
- HTTPS `/tienda/` responde HTTP 200.

## Evento identificable para evidencia

```bash
curl -k -sS -o /dev/null -w 'HTTP %{http_code}\n' \
'https://nodosur07.tas/tienda/?evidencia=tas-20260908'
```

La lectura directa del archivo de access log se reserva para `tas_revision` o la cuenta bootstrap/recovery de `.58`, porque las cuentas operativas no poseen sudo arbitrario sobre `grep`/`tail`:

```bash
sudo grep 'evidencia=tas-20260908' /var/log/apache2/nodosur_ssl_access.log
```

Resultado validado el 08-09-2026: petición desde VPN registrada con `GET /tienda/?evidencia=tas-20260908` y HTTP 200.

## Diagnóstico con cuenta operativa

Las cuentas de `nodosur-ops` pueden validar la configuración de Apache y consultar el journal del servicio:

```bash
sudo /usr/sbin/apache2ctl configtest
systemctl is-active apache2
systemctl is-active php8.3-fpm
journalctl -u apache2 -n 20 --no-pager
journalctl -u php8.3-fpm -n 20 --no-pager
```

`apache2ctl configtest` debe devolver `Syntax OK`.

## Inspección administrativa ampliada

Si se requiere leer directamente el archivo de error de Apache, utilizar `tas_revision` o la cuenta bootstrap/recovery:

```bash
sudo tail -n 50 /var/log/apache2/nodosur_ssl_error.log
```
