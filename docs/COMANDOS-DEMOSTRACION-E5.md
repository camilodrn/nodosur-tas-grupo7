# E5 — Comandos de demostración paso a paso

**Grupo 7 · 27/11/2026 · v0.2 (25/11/2026)**

Guía operativa basada en el [ensayo del 25/11](../evidencias/e5/ENSAYO-INCIDENTE-20261125.md). No es un script. Copiar un bloque a la vez, en la terminal indicada; detenerse si el resultado no coincide. Las comprobaciones y el temporizador propuestos no se han vuelto a ensayar. No ejecutar la interrupción ni la restauración sin autorización del docente y confirmación del entorno. No mostrar secretos.

## 0. Preparar las terminales

En Fedora, conectado a la red/VPN institucional, verificar las IP actuales en iLab antes de abrir las sesiones. Son las últimas conocidas, no IP estáticas garantizadas.

**DNS — VM268**
```bash
ssh tas_revision_e3@10.33.195.218
```
**Web1 — VM263**
```bash
ssh tas_revision_e3@10.33.195.183
```
**Web2 — VM310**
```bash
ssh tas_revision_e3@10.33.195.197
```
**Base de datos — VM279**
```bash
ssh tas_revision_e3@10.33.195.226
```
**Proxy y monitoreo — VM308**
```bash
ssh nodosur-g7-proxy@10.33.195.194
```
En cada VM, comprobar identidad y dirección:
```bash
hostname
ip -br addr
```
Comparar con [INVENTARIO.md](../INVENTARIO.md). Si difiere, no ejecutar cambios.

## 1. Mostrar el estado inicial

**VM268:** DNS y NFS.
```bash
systemctl is-active named nfs-kernel-server
```
Esperado: ambos active.

**VM263, VM310, VM279 y VM308:** revisar contenedores en cada una.
```bash
sudo docker ps --format 'table {{.Names}}\t{{.Status}}'
```
Esperado: web1, web2, MariaDB, HAProxy y servicios de monitoreo activos según su host.

**Fedora:** registrar UTC y consultar la portada y el producto 45 (Taller de alfarería).
```bash
date -u
curl -ksS -o /dev/null -w 'Portada HTTP %{http_code}\n' https://nodosur07.tas/
curl -ksS -o /dev/null -w 'Producto HTTP %{http_code} | %{time_total} s\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Esperado: 200 en ambas. Abrir la tienda desde el menú del CMS. La opción -k omite la confianza TLS; no demuestra identidad del servidor.

**Observabilidad:** abrir https://nodosur07.tas/grafana/ y los accesos autorizados a Prometheus y Mailpit. Mostrar mysql_up=1, probe_success=1 para las sondas HTTP/DNS y ausencia de alertas activas. En el ensayo hubo 12/12 targets disponibles; el panel filtrado muestra 8, no 12.

## 2. Mostrar DNS y HTTPS

**Fedora**
```bash
dig @10.33.195.218 nodosur07.tas A
getent hosts nodosur07.tas
curl -I https://nodosur07.tas/
```
Esperado: NOERROR, aa, A hacia HAProxy (10.33.195.194 si no cambió); el cliente resuelve el mismo nombre. Si curl falla por certificado autofirmado, explicar la confianza y no confundirlo con una caída. No cambiar DNS del cliente sin autorización.

**VM268:** localizar la configuración efectiva de la zona (lectura).
```bash
sudo grep -R -n 'nodosur07.tas' /etc/bind
```
Identificar el archivo de zona referenciado y mostrar su registro A; no editarlo. Si la IP cambió, detenerse y verificar inventario/resolución antes de seguir.

## 3. Incidente autorizado de MariaDB

**VM279:** comprobar identidad, servicio y volumen original.
```bash
hostname
systemctl is-active nodosur-db-prod.service
sudo docker inspect -f '{{.State.Health.Status}} {{range .Mounts}}{{.Name}} {{end}}' nodosur-db-staging
```
Esperado: svr-db-nodosur07, active, healthy y volumen nodosur-db-staging_db_stage_data. Si no coincide, detenerse.

**Solo si el docente autoriza interrumpir ese entorno:** acordar operador único, ventana, respaldo y reversión. El ensayo usó un temporizador de rescate de cinco minutos. Esta sintaxis de temporizador es propuesta y debe verificarse antes de detener MariaDB; no es una garantía de arranque.

```bash
RESCATE="nodosur-e5-rescate-$(date +%s)"
sudo systemd-run --unit="$RESCATE" --on-active=5min /usr/bin/systemctl start nodosur-db-prod.service
systemctl list-timers "$RESCATE.timer" --no-pager
```
Si no aparece el temporizador activo con próxima ejecución, NO detener MariaDB. Mantener abierta esta terminal.

**VM279 — cambio de estado autorizado:**
```bash
date -u
sudo systemctl stop nodosur-db-prod.service
sudo docker ps -a --filter name=nodosur-db-staging
```
Esperado: Exited; no se elimina el volumen. Nunca usar down -v.

**Fedora — repetir la misma operación que al inicio:**
```bash
date -u
dig @10.33.195.218 nodosur07.tas A
curl -ksS -o /dev/null -w 'Producto HTTP %{http_code}\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Esperado tras detección: DNS sigue respondiendo, producto HTTP 503. Grafana: mysql_up=0, sondas HTTP=0 y DNS=1; Mailpit: FIRING. Si no aparece, registrar lo observado; no fabricar una alerta.

**VM308:** revisar logs del proxy durante el incidente.
```bash
sudo docker logs --since 10m nodosur-haproxy 2>&1 | tail -n 60
```
Buscar DOWN de ambos backends y 503. El scrape up=1 no significa aplicación sana.

**VM279 — recuperar antes del temporizador, sin esperar innecesariamente:**
```bash
date -u
sudo systemctl start nodosur-db-prod.service
sudo docker ps --filter name=nodosur-db-staging
sudo docker inspect -f '{{.State.Health.Status}}' nodosur-db-staging
```
Esperar healthy; si falla, escalar y mantener la recuperación prioritaria. Solo tras verificar el CMS recuperado, retirar el temporizador propio, en la misma terminal donde se definió RESCATE:
```bash
test -n "$RESCATE" && sudo systemctl stop "$RESCATE.timer"
```
No cancelar otros temporizadores.

## 4. Restauración de datos — únicamente copia aislada

**VM279.** No tocar la base original. El ensayo usó la copia nodosur-e5-evaluacion, sin red ni puertos, con volumen nodosur-e5-evaluacion-data. Si no existe o difiere, no crear ni reconstruir a ciegas: recuperar el procedimiento aprobado.

```bash
sudo docker inspect -f '{{.Name}} red={{.HostConfig.NetworkMode}} puertos={{json .HostConfig.PortBindings}} {{range .Mounts}}{{.Name}}:{{.Destination}} {{end}}' nodosur-e5-evaluacion
sudo docker inspect -f '{{.State.Health.Status}}' nodosur-e5-evaluacion
sudo sha256sum /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz
sudo gzip -t /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz && echo 'GZIP OK'
```
Esperado: red none, sin puertos, volumen de evaluación en /var/lib/mysql, healthy, GZIP OK. SHA-256 esperado:
```text
aeb7c21e64147c018070dd8c6378e839ec7ab3ed02a6b505a4cdc1c2e7550699
```
Si no coincide, no continuar. El archivo es el respaldo específico de evaluación, no el backup automático original.

**Consultar el testigo (lectura):**
```bash
sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final' <<'SQL'
SELECT option_id, option_name, option_value
FROM wp_options WHERE option_name = 'nodosur_e5_testigo';
SQL
```
Esperado: ID 8603, nodosur_e5_testigo, NODOSUR-E5-RECUPERACION-20261125. La contraseña se lee dentro del contenedor sin imprimirla.

**Solo si el docente autoriza repetir la pérdida del dato académico y el resultado anterior es exactamente una fila:** eliminar únicamente ese registro en la copia aislada. Si ya está ausente, no eliminar nada; confirmar ausencia y seguir.
```bash
sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final' <<'SQL'
DELETE FROM wp_options
WHERE option_id = 8603
AND option_name = 'nodosur_e5_testigo'
AND option_value = 'NODOSUR-E5-RECUPERACION-20261125';
SELECT ROW_COUNT() AS filas_eliminadas;
SELECT COUNT(*) AS testigos FROM wp_options
WHERE option_name = 'nodosur_e5_testigo';
SQL
```
Esperado: 1 fila eliminada y 0 testigos. Si difiere, detenerse; no ampliar el DELETE.

**Restaurar el respaldo comprobado a la misma copia (sobrescribe sus datos; nunca los originales):**
```bash
(
  set -o pipefail
  time sudo gzip -dc /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz | sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final'
)
```
Esperado: importación sin errores. No seguir si el bloque falla. En el ensayo demoró 2,924 s; la duración nueva puede variar.

**Validar después:**
```bash
sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final' <<'SQL'
SELECT COUNT(*) AS tablas FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';
SELECT option_id, option_name, option_value
FROM wp_options WHERE option_name = 'nodosur_e5_testigo';
SQL
```
Esperado: 52 tablas y mismo testigo recuperado. Comprobar ambos contenedores:
```bash
sudo docker ps --filter name=nodosur-db-staging --filter name=nodosur-e5-evaluacion
```
El CMS original y la copia SQL son entornos distintos; no afirmar que WordPress funciona sobre la copia.

## 5. Validación final

**Fedora**
```bash
date -u
dig @10.33.195.218 nodosur07.tas A
curl -ksS -o /dev/null -w 'Portada HTTP %{http_code}\n' https://nodosur07.tas/
curl -ksS -o /dev/null -w 'Producto HTTP %{http_code}\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Esperado: 200 y DNS operativo. Abrir tienda. En Grafana comprobar recuperación de las sondas y mysql_up=1; en Mailpit buscar RESOLVED. Registrar horas reales. Para mostrar el ensayo anterior, seleccionar 25/11, 12:49–12:58 UTC (09:49–09:58 Chile continental).

**VM308 — verificar el dashboard instalado (lectura):**
```bash
cd ~/nodosur-tas-grupo7
python3 -m json.tool compose/monitoreo/dashboards/nodosur-e4.json > /dev/null && echo 'JSON OK'
sha256sum compose/monitoreo/dashboards/nodosur-e4.json
sudo docker ps --filter name=nodosur-monitoreo-grafana-1
```
Referencia: 23 paneles, commit 34d8d06, SHA-256 589b6857241d80f0500820a3a6054fcdb152359f61802edd8e8590a81bf3beaf. No reiniciar ni actualizar Git en VM por rutina.

## 6. Defensa individual

Explicar: DNS resuelve; HAProxy retira backends no saludables; ambos WordPress dependen de una MariaDB única. Prometheus distingue scrape de salud funcional; Alertmanager notifica a Mailpit. Reiniciar el servicio original recupera disponibilidad; importar el backup aislado recupera datos. El ensayo registró 42 s de detección, 112 s hasta el primer aviso, aproximadamente 4 min 45 s de recuperación funcional y 2,924 s de importación SQL. No equivalen al RTO/RPO integral.

**Antes del viernes:** comprobar acceso vigente, temporizador, autorización de interrupción, ruta real de zona y accesos a observabilidad. Cotejar pauta original, especialmente si requiere verificar el dato restaurado desde un CMS conectado a la copia. No afirmar que esa última prueba está realizada. No se realizaron cambios en las VMs para redactar esta guía.
