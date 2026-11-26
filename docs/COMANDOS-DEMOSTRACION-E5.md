# E5 — Demostración en vivo: guía fácil para todo el equipo

**Grupo 7 · 27/11/2026 · v0.5 (26/11/2026)**

Esta es la guía para usar delante del profesor. No es necesario memorizar comandos. Cada paso dice dónde hacerlo, qué copiar y qué mostrar. Ejecutar un bloque a la vez; no copiar toda la página. La pauta del profesor tiene seis etapas. La falla de MariaDB está autorizada según el equipo; coordinar el momento con el docente.

[Versión técnica v0.3 (detalle y validaciones)](https://github.com/camilodrn/nodosur-tas-grupo7/blob/b1b32a64c965c31b43802b6bc7d39acfc8ef8b36/docs/COMANDOS-DEMOSTRACION-E5.md) · [Ensayo del 25/11](../evidencias/e5/ENSAYO-INCIDENTE-20261125.md) · [Inventario](../INVENTARIO.md)

## Antes de empezar (hacerlo antes de que llegue el profesor)

### A. Abrir las terminales

Desde Fedora, abrir una pestaña por VM y ponerle el nombre de la primera columna. Mantener también una terminal Fedora libre, sin SSH. Los cinco hostnames reales se estandarizaron el 26/11; no volver a cambiarlos durante la defensa. Las IP se verificaron el 26/11, pero pueden variar por DHCP: confirmar en iLab.

| Pestaña | Hostname que debe aparecer al ejecutar hostname | Acceso desde Fedora |
| --- | --- | --- |
| VM263 WEB1 | vm263-web1 | ssh tas_revision_e3@10.33.195.183 |
| VM268 DNS | vm268-dns-nfs | ssh tas_revision_e3@10.33.195.218 |
| VM279 BD | vm279-mariadb | ssh tas_revision_e3@10.33.195.226 |
| VM308 PROXY | vm308-proxy-monitor | ssh nodosur-g7-proxy@10.33.195.194 |
| VM310 WEB2 | vm310-web2 | ssh tas_revision_e3@10.33.195.197 |

**FEDORA → pestaña VM263 WEB1**
```bash
ssh tas_revision_e3@10.33.195.183
```
**FEDORA → pestaña VM268 DNS**
```bash
ssh tas_revision_e3@10.33.195.218
```
**FEDORA → pestaña VM279 BD**
```bash
ssh tas_revision_e3@10.33.195.226
```
**FEDORA → pestaña VM308 PROXY**
```bash
ssh nodosur-g7-proxy@10.33.195.194
```
**FEDORA → pestaña VM310 WEB2**
```bash
ssh tas_revision_e3@10.33.195.197
```
En cada pestaña SSH:
```bash
hostname
ip -br addr
```
Si la identidad no coincide, detenerse. Cada integrante debe saber dónde está ejecutando comandos. No escribir contraseñas en la guía ni mostrarlas al profesor.

### B. Dejar listo el navegador

**VM308 PROXY — confirmar la IP interna de Prometheus:**
```bash
sudo docker inspect -f '{{range $name, $net := .NetworkSettings.Networks}}{{println $name $net.IPAddress}}{{end}}' nodosur-monitoreo-prometheus-1
```
El 25/11 la red nodosur-monitoreo_default tenía 172.19.0.2; el 26/11 se confirmó acceso a la API de Prometheus en esa IP. Si cambió, ajustar solo el destino Prometheus del túnel.

**FEDORA — pestaña nueva llamada TÚNEL (no dentro de una VM):**
```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:19090:172.19.0.2:9090 \
  -L 127.0.0.1:19093:127.0.0.1:9093 \
  -L 127.0.0.1:18025:127.0.0.1:8025 \
  nodosur-g7-proxy@10.33.195.194
```
Ingresar contraseña. **Si la terminal queda en blanco, está bien.** No cerrarla. Abrir estas páginas desde el navegador de Fedora (no desde la VM):

| Pestaña del navegador | Dirección | Qué se muestra |
| --- | --- | --- |
| CMS | https://nodosur07.tas/ | Sitio web y tienda |
| Grafana | https://nodosur07.tas/grafana/ | Dashboard y gráficos |
| Prometheus | http://localhost:19090/targets | 12 targets |
| Alertmanager | http://localhost:19093/ | Alertas activas |
| Mailpit | http://localhost:18025/ | Correos FIRING y RESOLVED |

Grafana y CMS usan HAProxy; no necesitan túnel. El certificado es autofirmado: la advertencia de confianza ya es conocida. No confundirla con una caída. Si no pueden abrir alguna página, resolverlo antes de provocar la falla.

### C. Repartir roles

Propuesta: operador BD (único que detiene, arranca y restaura), operador DNS, operador observabilidad y operador cliente/coordinador. Acordar los nombres entre los cuatro. Todos deben poder explicar el conjunto. Mantener una sola persona a cargo de las acciones que cambian el estado.

---

## 1. Servicios operativos

**Objetivo:** demostrar que el proyecto funciona antes de causar la falla.

**1.1 — VM268 DNS:** 
```bash
systemctl is-active named nfs-kernel-server
```
Debe aparecer active dos veces.

**1.2 — VM263 WEB1, VM310 WEB2, VM279 BD y VM308 PROXY:** copiar este mismo comando en cada una de esas cuatro pestañas, una por una.
```bash
sudo docker ps
```
Mostrar los contenedores correspondientes: WordPress web1/web2, MariaDB original healthy, proxy y observabilidad. No detener nada.

**1.3 — FEDORA:** comprobar la operación del producto 45 (Taller de alfarería).
```bash
date -u
curl -ksS -o /dev/null -w 'HTTP %{http_code} | %{time_total} s\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Debe salir HTTP 200. Abrir también la tienda en el navegador. Esta consulta depende de MariaDB. Guardar la hora UTC. Se repetirá exactamente la misma consulta en los pasos 3 y 5. -k omite confianza TLS; no valida identidad.

**Explicar:** DNS resuelve; HAProxy recibe HTTPS y balancea entre dos WordPress. Ambos dependen de MariaDB y comparten uploads por NFS.

## 2. Registro A del DNS

**2.1 — VM268 DNS:** mostrar la configuración real.
```bash
sudo cat /etc/bind/named.conf.local
sudo cat /etc/bind/db.nodosur07.tas
sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
```
Señalar al profesor: @ IN A 10.33.195.194 y www IN A 10.33.195.194. La validación debe decir OK.

**2.2 — FEDORA:**
```bash
dig @10.33.195.218 nodosur07.tas A +norecurse
getent hosts nodosur07.tas
```
Buscar NOERROR, aa y 10.33.195.194. Abrir el CMS por https://nodosur07.tas/ en el navegador.

**Explicar:** la IP pertenece a HAProxy (VM308), no a WordPress. DNS no transporta el tráfico web.

## 3. Observabilidad e incidente

### 3.1 — NAVEGADOR: mostrar antes de la caída

Grafana: WordPress y tienda = 1; DNS = 1; MariaDB = 1; alertas activas = 0. Prometheus: 12 targets UP. Alertmanager: sin alertas activas. Mailpit conserva correos del ensayo anterior: distinguirlos por hora de los nuevos.

El panel de Grafana «Targets disponibles» cuenta 8 targets filtrados, no los 12 de Prometheus. Seleccionar un rango reciente (por ejemplo, últimos 15 minutos) y refresco de 30 s. Usar horas del incidente actual.

### 3.2 — VM279 BD: verificar antes de detener

```bash
hostname
systemctl is-active nodosur-db-prod.service
sudo docker inspect -f '{{.State.Health.Status}} {{range .Mounts}}{{.Name}} {{end}}' nodosur-db-staging
```
Debe ser vm279-mariadb, active, healthy, volumen nodosur-db-staging_db_stage_data. Si difiere, NO detener. Asegurar respaldo y que el docente indique el momento.

### 3.3 — VM279 BD: programar el rescate de emergencia

```bash
RESCATE="nodosur-e5-rescate-$(date +%s)"
sudo systemd-run --unit="$RESCATE" --on-active=5min --timer-property=AccuracySec=1s /usr/bin/systemctl start nodosur-db-prod.service
systemctl list-timers "$RESCATE.timer" --no-pager
```
Debe aparecer el temporizador con próxima ejecución en el futuro. Si no aparece o hay error, **NO detener MariaDB**. Mantener esta misma terminal abierta. Es un intento automático de arranque, no una garantía. El mecanismo se probó con echo; la variante AccuracySec=1s no se volvió a ensayar.

### 3.4 — VM279 BD: provocar la falla (solo operador BD)

```bash
date -u
sudo systemctl stop nodosur-db-prod.service
sudo docker ps -a --filter name=nodosur-db-staging
```
Debe quedar Exited. No se borra el volumen. **No usar docker compose down -v.** Registrar hora.

### 3.5 — FEDORA: mostrar que la operación falla

```bash
date -u
curl -ksS -o /dev/null -w 'HTTP %{http_code} | %{time_total} s\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
dig @10.33.195.218 nodosur07.tas A +norecurse
```
Esperar HTTP 503 después de que HAProxy retire los backends. DNS sigue NOERROR. Si la primera consulta todavía no falla, repetir tras unos segundos; registrar el resultado real.

### 3.6 — NAVEGADOR y VM308 PROXY: explicar la causa

- Grafana: mysql_up cae a 0, portada y tienda a 0; DNS sigue en 1.
- Prometheus / Alerts y Alertmanager: observar alertas pendientes o FIRING.
- Mailpit: buscar los nuevos mensajes FIRING de MariaDB y HTTP (por hora). En el ensayo llegaron en aproximadamente 2 y 3 minutos; no son plazos garantizados.

**VM308 PROXY — mostrar logs:**
```bash
sudo docker logs --since 10m nodosur-haproxy 2>&1 | tail -n 60
```
Buscar DOWN y HTTP 503. Ambos backends dependen de la misma BD. El exporter puede seguir UP aunque MariaDB esté caída. No esperar más de lo acordado solo para obtener alertas; recuperar a tiempo.

### 3.7 — VM279 BD: recuperar el servicio

```bash
date -u
sudo systemctl start nodosur-db-prod.service
sudo docker ps --filter name=nodosur-db-staging
```
Esperar healthy. Si no recupera, detener la demostración y diagnosticar; no borrar volúmenes ni reiniciar todo.

**FEDORA — comprobación rápida antes de restaurar datos:**
```bash
curl -ksS -o /dev/null -w 'HTTP %{http_code}\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Esperar 200. Solo entonces, **VM279 BD**, en la misma terminal que creó RESCATE:
```bash
test -n "$RESCATE" && sudo systemctl stop "$RESCATE.timer"
```
Si el temporizador ya se ejecutó y desapareció, consultar su journal. No cancelar otros temporizadores.

## 4. Restauración de datos (SOLO copia de evaluación)

**Todos los comandos de esta etapa van en VM279 BD.** El servicio original nodosur-db-staging ya debe estar healthy. No importaremos ningún respaldo sobre producción.

### 4.1 — Revisar la copia y el respaldo

```bash
sudo docker inspect -f '{{.Name}} red={{.HostConfig.NetworkMode}} puertos={{json .HostConfig.PortBindings}} {{range .Mounts}}{{.Name}}:{{.Destination}} {{end}}' nodosur-e5-evaluacion
sudo docker inspect -f '{{.State.Health.Status}}' nodosur-e5-evaluacion
sudo ls -lh /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz
sudo gzip -t /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz && echo 'GZIP OK'
sudo sha256sum /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz
```
Debe salir nodosur-e5-evaluacion, red none, sin puertos, volumen nodosur-e5-evaluacion-data en /var/lib/mysql y healthy. Respaldo 25/11 12:31 UTC, 384 KiB, GZIP OK y SHA-256:
```text
aeb7c21e64147c018070dd8c6378e839ec7ab3ed02a6b505a4cdc1c2e7550699
```
Si algo difiere, NO ejecutar DELETE ni restauración. No mostrar ni leer contraseñas en pantalla.

### 4.2 — Mostrar el dato testigo presente

```bash
sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final' <<'SQL'
SELECT option_id, option_name, option_value
FROM wp_options WHERE option_name = 'nodosur_e5_testigo';
SQL
```
Debe aparecer exactamente una fila: 8603, nodosur_e5_testigo, NODOSUR-E5-RECUPERACION-20261125. Si ya está ausente, confirmar 0 filas y pasar a 4.4; si aparece algo distinto, detenerse.

### 4.3 — Simular pérdida del dato (solo copia)

Solo si 4.1 y 4.2 coinciden y se acordó con el docente. Se elimina exclusivamente el registro académico identificado.

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
Mostrar al profesor: filas_eliminadas = 1, testigos = 0. Si no coincide, NO ampliar el DELETE.

### 4.4 — Restaurar el respaldo

Confirmar nuevamente el destino: nodosur-e5-evaluacion. La importación sobrescribe datos de la copia, nunca del original. Copiar todo este bloque:

```bash
(
  set -o pipefail
  time sudo gzip -dc /root/nodosur-e5-evaluacion/respaldo-e5-20261125.sql.gz | sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final'
)
```
Esperar sin errores. Registrar el tiempo real; el ensayo demoró 2,924 s. Si hay error, no afirmar éxito.

### 4.5 — Comprobar que reapareció el dato

```bash
sudo docker exec -i nodosur-e5-evaluacion sh -c 'export MYSQL_PWD="$(cat /run/secrets/root_password)"; exec mariadb -uroot nodo_sur_final' <<'SQL'
SELECT option_id, option_name, option_value
FROM wp_options WHERE option_name = 'nodosur_e5_testigo';
SELECT COUNT(*) AS tablas FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';
SQL
```
Mostrar el mismo ID, nombre, valor y 52 tablas. Antes había 0 testigos y ahora 1: esa es la evidencia pedida.

```bash
sudo docker ps --filter name=nodosur-db-staging --filter name=nodosur-e5-evaluacion
```
Ambos deben quedar healthy.

**Explicar:** recuperar el servicio original y restaurar datos en una copia aislada son pruebas distintas. La pauta exige la copia de evaluación; no se conectó otro WordPress a ella.

## 5. Validación final

**5.1 — FEDORA:** repetir la consulta inicial.
```bash
date -u
dig @10.33.195.218 nodosur07.tas A +norecurse
curl -ksS -o /dev/null -w 'HTTP %{http_code} | %{time_total} s\n' https://nodosur07.tas/wp-json/wc/store/v1/products/45
```
Mostrar HTTP 200 y CMS por nombre, tienda operativa. Registrar hora.

**5.2 — NAVEGADOR:** Grafana: mostrar gráfico «Disponibilidad funcional y dependencias» con la caída y recuperación. MariaDB, portada, tienda y DNS en 1. Prometheus: 12 targets UP. Alertmanager: sin alertas activas una vez normalizado. Mailpit: nuevos RESOLVED del incidente, distinguibles por hora. Pueden tardar; no confundir correos viejos con nuevos.

**5.3 — VM279 BD:** mostrar que el dato recuperado sigue presente (repetir SELECT del paso 4.5 si lo solicita el profesor).

**Explicar:** el CMS volvió a funcionar y el dato reapareció en la copia. No afirmar que se reconstruyó toda la infraestructura desde cero ni que existe alta disponibilidad integral.

## 6. Defensa individual

Cada integrante ejecuta o interpreta una comprobación y responde una pregunta. Ejemplos:
- DNS: ¿por qué apunta al proxy? Porque es el punto de entrada.
- HAProxy: ¿por qué caen ambos backends si la BD falla? Ambos dependen de una MariaDB única.
- BD: ¿por qué no se perdió el volumen al detener? stop detiene el contenedor; no elimina el volumen.
- Observabilidad: ¿por qué up=1 no garantiza mysql_up=1? El primero mide el scrape; el segundo la conectividad del exporter con MariaDB.
- Restauración: ¿qué demuestra pasar de 0 a 1 testigo? Que el respaldo recupera el dato en la copia.
- Riesgo: HAProxy, MariaDB, DNS y NFS son puntos únicos de falla.

## Cierre y límites

- Validación posterior al cambio de hostname (26/11): cinco nodenames correctos en `node_uname_info`, 12/12 targets `up=1`, 4/4 `probe_success=1`, `mysql_up=1`, ambos backends HTTP 200, Grafana `database=ok`, cero alertas activas en Prometheus. Desde Fedora: DNS correcto, página del producto 45 e inicio de sesión Grafana HTTP 200 siguiendo redirecciones con `curl -k -L`. No se repitió la falla ni la restauración. Se conservan usuarios SSH, rutas, contenedores, IP y alias locales; persistencia tras reinicio y siguientes respaldos automáticos pendientes de comprobar.

- Ensayo 25/11: 42 s detección, 112 s primera notificación interna, aprox. 4 min 45 s recuperación funcional, 2,924 s importación SQL. No equivalen a RTO/RPO integral. La defensa del 27/11 tendrá sus propios tiempos.
- Lecturas, rutas, autenticación, checksum, DNS, métricas y accesos se comprobaron el 25/11. El túnel con bind explícito y el temporizador AccuracySec=1s son variantes propuestas; no se reensayaron. Las acciones de detención/importación no se repitieron después del ensayo. No afirmar que se verificó el ensayo del 26/11: el equipo reportó dificultades de uso sin detallar sus resultados.
- Si algo falla, priorizar devolver el servicio a estado operativo y registrar lo ocurrido. No borrar datos ni modificar configuraciones por improvisación.
- Al finalizar, cerrar el túnel con Ctrl+C en Fedora; no afecta a las VM. La guía v0.3 conserva el detalle técnico y las validaciones previas.
