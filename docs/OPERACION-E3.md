# Operación, pruebas y diagnóstico E3

Los siguientes comandos de VM son un procedimiento para operadores autorizados. **No fueron ejecutados durante la auditoría local.** Evitar `docker inspect` completo, `compose config` con credenciales en variables, volcados de cookies o SQL en la evidencia pública. Registrar fecha con zona horaria, VM, commit/configuración efectiva, comando, código de salida y salida saneada.

## Chequeos sin cambios de configuración

Desde cliente VPN/laboratorio:

```bash
bash scripts/validate-dns.sh
NODOSUR_CA_CERT=/ruta/segura/nodosur07.crt bash scripts/validate-web.sh
openssl s_client -connect 10.33.195.194:443 -servername nodosur07.tas \
  -CAfile /ruta/segura/nodosur07.crt -verify_hostname nodosur07.tas -verify_return_error </dev/null
```

Repetir validación de nombre para `www.nodosur07.tas`. Guardar solo SAN, issuer, vigencia, fingerprint público y resultado de verificación, nunca la clave. No usar `-k` como evidencia de confianza. La redirección HTTP debe ser a HTTPS canónico; portada, tienda, carrito y cuenta deben responder 200 en una sesión sin autenticación según la configuración actual.

Para capturar diez solicitudes sin cookies:

```bash
for i in $(seq 1 10); do
  printf 'Petición %s\n' "$i"
  curl --cacert /ruta/segura/nodosur07.crt --connect-timeout 5 --max-time 20 \
    -sS -D - -o /dev/null https://nodosur07.tas/ \
    | tr -d '\r' | grep -Ei '^HTTP/|^x-nodosur-backend:'
done
```

El bucle es captura, no aserción automática: comprobar diez respuestas 200 y distribución. Un 5/5 es esperado sin tráfico concurrente ni cambios de salud, no una garantía estadística de cada grupo de diez en un sistema activo. Mantener `X-NodoSur-Backend` durante la defensa permite atribuir respuestas; retirarlo después si se desea reducir exposición de topología.

## Estado por VM

En hosts Docker, usar cuenta administrativa autorizada:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
systemctl --failed --no-pager
```

| VM | Consultas |
|---|---|
| 268 | `systemctl is-active named nfs-server`; `sudo named-checkconf`; `sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas`; `sudo exportfs -v`; `findmnt`; espacio en filesystem de uploads y archive |
| 263 | `systemctl status nodosur-web1 nodosur-docker-firewall-web1 --no-pager`; `findmnt -M /srv/nodosur/nfs/uploads`; `docker logs --tail 50 nodosur-web1` |
| 310 | equivalente `web2`; `docker logs --tail 50 nodosur-web2` |
| 279 | `bash scripts/validate-db-local.sh` después de instalar el helper E3; `docker inspect -f '{{.State.Health.Status}}' nodosur-db-staging`; `docker logs --tail 50 nodosur-db-staging` |
| 308 | `systemctl status nodosur-proxy nodosur-proxy-firewall --no-pager`; `docker logs --tail 100 nodosur-haproxy` |

Los logs pueden contener IPs y datos de solicitudes; sanear antes de publicar. `active (exited)` no acredita contenedor activo. El helper DB E3 comprueba salud y muestra el puerto; no acredita permisos de aplicación ni la cantidad de tablas. Para estos últimos, usar una consulta fija con credenciales por archivo, nunca por argumento, desde la cuenta administrativa.

```sql
SELECT ENGINE, COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA='nodo_sur_final' GROUP BY ENGINE;
SELECT COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA='nodo_sur_final' AND TABLE_TYPE='BASE TABLE';
```

Esperado histórico: 52 tablas. Verificar motor InnoDB antes de afirmar consistencia de `single-transaction`. No publicar datos de clientes ni listar `mysql.user` completo.

## Matriz de conectividad

Usar `nc -z -w 3 DESTINO PUERTO` si está instalado y registrar éxito/error junto con contadores del firewall. Un timeout por sí solo no demuestra qué capa descartó el paquete.

| Desde | Destino | Esperado |
|---|---|---|
| VM263 y VM310 | `10.33.199.60 3306` | permitido |
| VM308 | `10.33.199.60 3306` | bloqueado |
| VM268 | `10.33.199.60 3306` | bloqueado con propuesta auditada; antes se permitía |
| VM308 | `.58 18081`, `.62 18080` | permitido |
| VM279 u otro cliente interno | `.58 18081`, `.62 18080` | bloqueado |
| cliente VPN/lab | `10.33.195.194 443` y 80 | permitido |
| VM279 | `10.33.195.194 443` | bloqueado |

Para respuesta HTTP directa a backends autorizados desde VM308:

```bash
curl --connect-timeout 5 --max-time 20 -sSI \
  -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' http://10.33.199.58:18081/
curl --connect-timeout 5 --max-time 20 -sSI \
  -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' http://10.33.199.62:18080/
```

Comprobar que encabezados `X-Forwarded-For/Proto` arbitrarios enviados al frontend se sustituyan por los efectivos; capturar únicamente los valores de diagnóstico mínimos en un entorno controlado. No habilitar endpoints públicos de depuración.

## Pruebas con cambios: ventana de laboratorio

Estas pruebas requieren intervención del operador y quedaron **sin ejecutar** en esta auditoría.

1. **Failover web2:** comprobar ambos activos y sin operaciones críticas; detener únicamente `nodosur-web2` vía systemd. Esperar transición DOWN en logs HAProxy, capturar solicitudes con tiempos y confirmar 200/web1. Volver a iniciar web2, esperar UP y capturar distribución. Usar el servicio del rol, no detener Docker global. Registrar tiempos para medir RTO; ante pérdida inesperada de servicio, restaurar web2 y diagnosticar.
2. **Reinicio Docker/VM:** realizar en un único backend mientras el otro responde. Comprobar NFS, firewall, unidad y contenedor después. Repetir por rol en ventanas independientes. El reinicio DB/proxy/DNS/NFS puede interrumpir todo el sitio; no confundir con la prueba de caída web2 ya registrada.
3. **Carrito compartido:** desde VM308, producto simple de prueba aprobado: `python3 pruebas/e3/carrito-coherencia.py --permitir-escritura --producto 43`. El ID 43 es histórico, comprobar existencia/disponibilidad. El script consulta el producto por API, crea sesión nueva, añade en web1, consulta en web2 y limpia. No realiza checkout. No imprime Cart-Token. Una falla de red tras una escritura puede dejar sesión residual: revisar la limpieza sin publicar token; no repetir indiscriminadamente.
4. **NFS RW compartido:** crear un archivo marcador de nombre único y contenido no sensible como UID PHP en web1, leerlo desde web2 y eliminar solo ese marcador. Registrar origen NFS, UID/GID y resultado. No modificar uploads existentes. Probar ausencia de NFS en una VM clonada para acreditar rechazo del arranque, sin desmontar NFS de producción.
5. **Subidas no ejecutables:** en laboratorio aislado, un archivo de prueba con extensión PHP en uploads debe responder 403 y una imagen inocua 200. Eliminar solo los marcadores. Verificar `apache2ctl configtest` antes.
6. **Restauración:** seguir [recuperación](RECUPERACION-E3.md), siempre sin red ni volumen productivo. Un GZIP válido no prueba que SQL restaure ni que la tienda completa funcione.

## Diagnóstico por síntoma

| Síntoma | Revisar primero | Acción propuesta |
|---|---|---|
| Apex resuelve `.202` | consulta directa a BIND vs resolver cliente, SOA serial | corregir zona/serial; después tratar caché, sin cambiar hosts a ciegas |
| HTTPS no conecta | VPN/ruta, listener, contadores DOCKER-USER, servicio proxy | contrastar origen permitido; no abrir 443 a cualquier origen |
| 503 HAProxy | estados DOWN, check HEAD/Host, DB y logs web | reparar dependencia común o backend; no relajar check a cualquier status |
| Bucle de redirecciones | WP_HOME/SITEURL, proxy headers, confianza de REMOTE_ADDR | corregir HTTPS efectivo en wp-config y coherencia entre backends |
| Carrito/sesión cambia al alternar | salts, prefijo, DB, plugins y cachés | alinear configuración y versiones; no ocultarlo con afinidad sin explicar causa |
| Web no arranca | journal unidad, montaje NFS real RW, archivo wp-config, firewall | restaurar dependencia; no crear un uploads local vacío como sustituto |
| Web bloqueado en I/O | disponibilidad NFS, `findmnt`, latencia, espacio | recuperar NFS; no usar unmount forzado ni mounts blandos como atajo |
| DB activa en systemd pero sin servicio | `docker ps`, health, volumen real, nativa 3306 | diagnosticar contenedor; evitar doble instancia o inicialización vacía |
| Backup falla | journal, espacio/inodos, salud DB, secreto legible, lock | resolver causa; no borrar respaldos válidos para forzar éxito |
| Copia remota ausente | archivo local + checksum, transporte, timer receptor | capturar configuración real de réplica; no asumir que timer local replica |

Para logs por unidad: `journalctl -u UNIDAD --since '30 minutes ago' --no-pager`. Para respaldos: `systemctl list-timers --all`, `systemctl status nodosur-db-backup.timer` y `journalctl -u nodosur-db-backup.service`. El volumen de logs Docker se limita a tres archivos de 10 MiB por servicio; no hay evidencia de alertas centralizadas ni de retención del journal.
