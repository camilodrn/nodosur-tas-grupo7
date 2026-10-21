# Matriz de flujos — Entrega 3 Nodo Sur

**Alcance:** redes del laboratorio, tal como se observaron en las pruebas y terminales facilitadas por el equipo. Separar **permitido/bloqueado observado** de **política esperada o aún sin prueba**. Un timeout no demuestra por sí solo si el responsable es DOCKER-USER, UFW u otra capa.

## Flujos contrastados con evidencia

| Origen | Destino | Protocolo/puerto | Política esperada | Resultado observado | Evidencia / límites |
|---|---|---|---|---|---|
| Cliente Fedora por VPN | HAProxy VM308 `10.33.195.194` | TCP 80 HTTP | Permitir | **HTTP 301** a `https://nodosur07.tas/` | [Prueba redirección](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt), `curl --resolve` |
| Cliente autorizado | HAProxy VM308 `10.33.195.194` | TCP 443 HTTPS | Permitir | **HTTP/2 200** en seis solicitudes históricas | [HTTPS](../evidencias/e3/https-haproxy.txt). Certificado autofirmado: sin prueba de confianza de CA |
| HAProxy VM308 `.61` | WordPress web1 VM263 `.58` | TCP 18081 HTTP interno | Permitir | **Conexión TCP correcta y GET del upload verificado SHA-256** | [Conectividad](../evidencias/e3/acceso-proxy-backends-20261020.txt) y [NFS web1/web2](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) |
| HAProxy VM308 `.61` | WordPress web2 VM310 `.62` | TCP 18080 HTTP interno | Permitir | **Conexión TCP correcta y GET del upload verificado SHA-256** | [Conectividad](../evidencias/e3/acceso-proxy-backends-20261020.txt) y [NFS web1/web2](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) |
| MariaDB VM279 `.60` | web1 VM263 `.58` | TCP 18081 | Bloquear | **No conecta: timeout** | [Matriz TCP](../evidencias/e3/acceso-proxy-backends-20261020.txt). Atribución exacta al firewall pendiente |
| MariaDB VM279 `.60` | web2 VM310 `.62` | TCP 18080 | Bloquear | **No conecta: timeout** | [Matriz TCP](../evidencias/e3/acceso-proxy-backends-20261020.txt). Atribución exacta al firewall pendiente |
| WordPress web1 VM263 `.58` | MariaDB VM279 `.60` | TCP 3306 | Permitir | **TCP OK** en ensayo posterior a reinicio | [DB firewall](../evidencias/e3/firewall-db-tras-reinicio.txt) |
| WordPress web2 VM310 `.62` | MariaDB VM279 `.60` | TCP 3306 | Permitir | **TCP OK** en ensayo posterior a reinicio | [DB firewall](../evidencias/e3/firewall-db-tras-reinicio.txt) |
| HAProxy VM308 `.61` | MariaDB VM279 `.60` | TCP 3306 | Bloquear | **Sin conexión** | [DB firewall](../evidencias/e3/firewall-db-tras-reinicio.txt); no se especifica mecanismo exacto del rechazo |
| WordPress web1 VM263 `.58` | NFS VM268 `.59` | NFSv4.1 TCP 2049 | Permitir | **Montaje NFS RW reportado por findmnt**, y contenido de uploads vía HTTP idéntico al NFS original | [NFS/webs](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt); montaje y exports vistos en sesiones previas, sin captura textual aquí |
| WordPress web2 VM310 `.62` | NFS VM268 `.59` | NFSv4.1 TCP 2049 | Permitir | **Montaje NFS RW reportado por findmnt**, contenido idéntico | Misma evidencia y límite anterior |

## Políticas DOCKER-USER efectivas en los dos backends

El equipo ejecutó `systemctl is-active`, `is-enabled`, `iptables -S DOCKER-USER` y `iptables -nvL DOCKER-USER` en ambas VMs. [Evidencia completa](../evidencias/e3/firewall-docker-user-web1-web2-20261021.txt).

| VM | Servicio | Regla efectiva de denegación | Contador DROP |
|---|---|---|---|
| VM263 web1 | `nodosur-docker-firewall.service` `active/enabled` | Origen distinto de `10.33.199.61/32`, destino original `10.33.199.58:18081/TCP`, `-j DROP` | 4 paquetes, 240 bytes |
| VM310 web2 | `nodosur-docker-firewall.service` `active/enabled` | Origen distinto de `10.33.199.61/32`, destino original `10.33.199.62:18080/TCP`, `-j DROP` | 4 paquetes, 240 bytes |

La regla no afecta a otros puertos por sí misma; el tráfico que no coincide puede quedar sujeto a otras cadenas y capas. Los contadores acreditan descartes, pero no determinan qué orígenes concretos causaron cada incremento. La conectividad de VM308 hacia ambos WordPress está comprobada con GET y hashes.

## Reglas y flujos adicionales aún por corroborar

| Flujo | Política esperada | Pendiente |
|---|---|---|
| VPN/laboratorio → SSH administrativo de cada VM | Permitir solo a redes/cuentas autorizadas | Verificar filtros efectivos y accesos, sin revelar secretos |
| Cliente VPN/laboratorio → DNS autoritativo VM268 | Permitir consultas UDP/TCP 53 según política | Guardar consultas directas `dig` UDP/TCP, AA/SOA y filtro AXFR |
| MariaDB VM279 → HTTPS administrativo del proxy VM308 | Bloquear según política documentada | Falta salida técnica versionada que acredite origen/destino |
| VM268 NFS/DNS → MariaDB VM279 TCP 3306 | Política histórica posiblemente permisiva | Comprobar decisión real antes de describirlo como bloqueado |
| Redes ajenas a las autorizadas → puertos HTTP de backends / DB | Bloquear | Verificación segura desde un origen de prueba autorizado para negativas |

## Aplicación y precauciones

Las reglas del firewall propuestas en el PR de auditoría de Codex son **código no desplegado**. En producción se ha observado `nodosur-docker-firewall.service` activo en web1/web2 y reglas DOCKER-USER; no confundir esos servicios reales con las nuevas unidades `nodosur-docker-firewall-web1.service`/web2 propuestas por Codex.

Las reglas efectivas de **web1 y web2 ya se capturaron**. Como mejora, contrastar políticas del proxy/DB y, si fuese requisito, persistencia de los filtros ante reinicios planificados. No modificar iptables, systemd, Docker ni red para recolectar evidencia. Conservar resultados y fecha de la prueba.
