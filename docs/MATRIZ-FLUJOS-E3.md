# Matriz de flujos — Entrega 3 Nodo Sur

**Alcance:** redes del laboratorio, tal como se observaron en las pruebas y terminales facilitadas por el equipo. Separar **permitido/bloqueado observado** de **política esperada o aún sin prueba**. Un timeout no demuestra por sí solo si el responsable es DOCKER-USER, UFW u otra capa.

## Flujos contrastados con evidencia

| Origen | Destino | Protocolo/puerto | Política esperada | Resultado observado | Evidencia / límites |
|---|---|---|---|---|---|
| Cliente Fedora por VPN | HAProxy VM308 `10.33.195.194` | TCP 80 HTTP | Permitir | **HTTP 301** a `https://nodosur07.tas/` | [Prueba redirección](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt), `curl --resolve` |
| Cliente autorizado | HAProxy VM308 `10.33.195.194` | TCP 443 HTTPS | Permitir | **HTTP/2 200** en seis solicitudes históricas | [HTTPS](../evidencias/e3/https-haproxy.txt). Certificado autofirmado: sin prueba de confianza de CA |
| HAProxy VM308 `.61` | WordPress web1 VM263 `.58` | TCP 18081 HTTP interno | Permitir | **Conexión TCP correcta y GET del upload verificado SHA-256** | [Conectividad](../evidencias/e3/acceso-proxy-backends-20261020.txt) y [NFS web1/web2](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) |
| HAProxy VM308 `.61` | WordPress web2 VM310 `.62` | TCP 18080 HTTP interno | Permitir | **Conexión TCP correcta y GET del upload verificado SHA-256** | [Conectividad](../evidencias/e3/acceso-proxy-backends-20261020.txt) y [NFS web1/web2](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) |
| **DNS/NFS VM268 `.59`** | **WordPress web1 VM263 `.58`** | **TCP 18081 HTTP interno** | **Bloquear** | **GET desde VM268: timeout, `curl exit 28`, `HTTP=000`** | [Prueba diferencial (21/10)](../evidencias/e3/segmentacion-origen-proxy-vs-dns-nfs-20261021.txt); sin respuesta HTTP, atribución exacta al firewall pendiente |
| **DNS/NFS VM268 `.59`** | **WordPress web2 VM310 `.62`** | **TCP 18080 HTTP interno** | **Bloquear** | **GET desde VM268: timeout, `curl exit 28`, `HTTP=000`** | [Misma prueba](../evidencias/e3/segmentacion-origen-proxy-vs-dns-nfs-20261021.txt); sin respuesta HTTP, atribución exacta al firewall pendiente |
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
| VM263 web1 | `nodosur-docker-firewall.service` `active` (anteriormente `enabled`) | Origen distinto de `10.33.199.61/32`, destino original `10.33.199.58:18081/TCP`, `-j DROP` | **7 paquetes, 420 bytes** (antes 4/240) |
| VM310 web2 | `nodosur-docker-firewall.service` `active` (anteriormente `enabled`) | Origen distinto de `10.33.199.61/32`, destino original `10.33.199.62:18080/TCP`, `-j DROP` | **7 paquetes, 420 bytes** (antes 4/240) |

La regla no afecta a otros puertos por sí misma; el tráfico que no coincide puede quedar sujeto a otras cadenas y capas. La [relectura del 21/10](../evidencias/e3/firewall-docker-user-web1-web2-20261021.txt) muestra el firewall activo en ambos hosts, las mismas reglas de descarte y un incremento de **+3 paquetes/+180 bytes por web** respecto de la captura anterior. Esto es coherente con los dos timeouts desde VM268, pero los contadores agregados no identifican por sí solos qué origen los causó. Desde VM308 se observaron HTTP 200 en las dos webs.

## Confirmaciones de puertos y permisos — VM279/VM308

[Consulta de solo lectura del 21/10](../evidencias/e3/permisos-publicacion-git-db-proxy-20261021.txt): en VM279 el secreto DB y directorio son root:root con modos 600/700; Docker publica `3306/tcp` solo en `10.33.199.60:3306`. En VM308 el certificado TLS (incluye clave privada) usa modo 640 root:UNKNOWN y su directorio modo 750; Docker publica 8080/8443 internos a `10.33.195.194:80/443`. `UNKNOWN` corresponde al nombre de grupo no resuelto en el host. La auditoría posterior confirmó que el GID 99 corresponde al grupo `haproxy` dentro del contenedor, que se ejecuta con UID/GID 99. El PEM está montado con `RW=false` y se comprobó su lectura efectiva mediante `test -r` bajo esa identidad ([evidencia](../evidencias/e3/haproxy-certificado-gid99-20261021.txt)). No fue necesario cambiar permisos. Esta prueba no constituye una auditoría exhaustiva de ACL ni de identidades del host. Los enlaces a IP concreta delimitan interfaz de escucha, **no sustituyen pruebas de firewall de origen**.

## Auditoría complementaria de VM279 y DNS (21/10/2026)

La [captura de reglas y consultas](../evidencias/e3/auditoria-firewall-db-dns-20261021.txt) confirma que el `FORWARD` de VM279 tiene política `DROP` y pasa primero por `DOCKER-USER`. Las excepciones observadas hacia el puerto 3306 son los orígenes `.59` (VM268 DNS/NFS), `.62` (web2) y `.58` (web1), antes de una regla `DROP` para los demás orígenes sobre el destino original `10.33.199.60:3306`; el contador DROP registra 4 paquetes. UFW está activo con entradas predeterminadamente denegadas y permisos explícitos para 3306 desde esas tres IP y SSH administrativo desde las redes `10.30.248.0/24` y `10.33.21.0/24`. **`RETURN` no certifica aceptación final** y los contadores no identifican origen ni instante de cada paquete. También persisten reglas para `13307` con contadores no nulos. La inspección posterior encontró **sin escucha TCP, sin publicación Docker y sin DNAT Docker** para ese puerto; su necesidad histórica no está confirmada.

En VM268 se observó inicialmente respuesta SOA autoritativa (`aa`, `NOERROR`, serial `2026102001`) sobre UDP y TCP y un AXFR completo de **9 registros desde Fedora por VPN**. Tras comprobar BIND 9.18.39, la zona primaria y ausencia de un NS secundario publicado, el operador respaldó y añadió `allow-transfer { none; };` **solo a la zona `nodosur07.tas`**, validó sintaxis y aplicó `rndc reconfig`. **La verificación posterior desde Fedora conservó SOA UDP/TCP autoritativo, `www`→`10.33.195.194`, y AXFR pasó a `REFUSED`** ([evidencia](../evidencias/e3/auditoria-firewall-db-dns-20261021.txt)). No prueba ACL de todas las redes ni ausencia de secundarios ocultos. No se tocaron NFS ni registros DNS.

## Reglas y flujos adicionales aún por corroborar

| Flujo | Política esperada | Pendiente |
|---|---|---|
| VPN/laboratorio → SSH administrativo de cada VM | Permitir solo a redes/cuentas autorizadas | Verificar filtros efectivos y accesos, sin revelar secretos |
| Cliente VPN/laboratorio → DNS autoritativo VM268 | Permitir SOA por UDP/TCP; AXFR solo según política de secundarios | SOA UDP/TCP autoritativo (`aa`), resolución A correcta. AXFR antes completado (9 registros); tras instalar restricción de zona, **`REFUSED` desde Fedora VPN**. Otras redes no probadas. |
| MariaDB VM279 → HTTPS administrativo del proxy VM308 | Bloquear según política documentada | Falta salida técnica versionada que acredite origen/destino |
| VM268 NFS/DNS → MariaDB VM279 TCP 3306 | Excepción observada en `DOCKER-USER` y UFW | La IP `.59` está exceptuada, pero el contador de regla es 0 y no hay ensayo de conexión desde VM268; comprobar necesidad y alcance, sin asumir aceptación final |
| Redes ajenas a las autorizadas → puertos HTTP de backends / DB | Bloquear | Verificación segura desde un origen de prueba autorizado para negativas |

## Aplicación y precauciones

Las reglas del firewall propuestas en el PR de auditoría de Codex son **código no desplegado**. En producción se ha observado `nodosur-docker-firewall.service` activo en web1/web2 y reglas DOCKER-USER; no confundir esos servicios reales con las nuevas unidades `nodosur-docker-firewall-web1.service`/web2 propuestas por Codex.

Las reglas efectivas de **web1 y web2 ya se capturaron**. Como mejora, contrastar políticas del proxy/DB y, si fuese requisito, persistencia de los filtros ante reinicios planificados. No modificar iptables, systemd, Docker ni red para recolectar evidencia. Conservar resultados y fecha de la prueba.
