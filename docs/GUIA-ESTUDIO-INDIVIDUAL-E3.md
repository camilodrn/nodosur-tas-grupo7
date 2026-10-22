# Nodo Sur · Guía de estudio individual para Entrega 3
**Taller de Administración de Sistemas · Grupo 7 · USM Sede Concepción · 22/10/2026**

> **Cómo será la evaluación:** el profesor revisará el puesto de cada equipo y podrá preguntar **a cualquiera de los integrantes**, pedir explicaciones de decisiones y solicitar **comandos en la terminal** para comprobar la implementación. **No es una exposición formal ante toda la sala.**
>
> Esta guía sirve para **estudiar y ejecutar consultas seguras**, no para memorizar una presentación. Se fundamenta en los archivos y las evidencias de esta entrega. Los ejemplos que dicen «ejecutar» son de lectura, salvo cuando explícitamente se indica otro efecto. No publicar contraseñas ni claves privadas.

## Índice de repaso rápido

1. Qué sistema hicimos y qué ocurre cuando un usuario entra.
2. Inventario de cinco VMs, redes y puertos.
3. Carpetas reales y **archivos de configuración activos:** NFS, WordPress, Docker, HAProxy, BIND9, MariaDB, firewall y systemd.
4. Comandos que podrían pedir en la terminal, agrupados por VM.
5. Los siete criterios de la rúbrica, con evidencia y límites.
6. Preguntas sorpresa con respuestas defendibles.
7. Diagnóstico de fallas por capas, sin romper servicios.
8. Preparación práctica por integrante y comprobación final.
9. Qué preguntar sobre infraestructura como código después de E3.

---

## Archivo de referencia: ¿qué archivo modificamos y dónde está la regla?

**Antes de memorizar rutas, estudiar el [mapa de archivos y configuraciones de E3](MAPA-CONFIGURACIONES-E3.md)**. Reúne por cada VM: carpeta de datos, archivo de configuración, archivo versionado en Git, regla activa y comando de solo lectura para mostrarla. Es especialmente importante para NFS: se comprobó el export /srv/nodosur/uploads y los montajes de las webs, pero **no está acreditado cuál archivo de exports modificó el equipo**. El mapa indica cómo verificar /etc/exports o /etc/exports.d en VM268 y /etc/fstab o una unidad .mount en cada cliente, sin adivinar ni modificar.

---

## 1. Explicar el sistema sin leer

**Versión de 30 segundos:**

«Nodo Sur es una tienda WordPress/WooCommerce. Separamos el servicio en cinco VMs: DNS y NFS, dos backends WordPress, una MariaDB y un proxy HAProxy. El DNS resuelve el dominio hacia HAProxy; el proxy recibe HTTPS y reparte peticiones entre los dos WordPress. Ambos usan la misma base de datos y comparten uploads mediante NFS. Así, si cae un backend, el otro puede seguir atendiendo. No es alta disponibilidad completa porque el proxy, la base de datos y NFS/DNS siguen siendo únicos».

**Recorrido correcto de una solicitud:**

1. El usuario escribe https://nodosur07.tas/ en el navegador.
2. Su equipo pregunta al servidor BIND9 de VM268 por la dirección del dominio; la respuesta A conocida es 10.33.195.194, la IP de acceso al **proxy**. DNS **no** transmite las solicitudes HTTP de WordPress.
3. El navegador conecta a VM308 por HTTPS/443. Docker publica ese puerto hacia 8443 del contenedor HAProxy. Por HTTP/80, HAProxy devuelve redirección 301 a HTTPS.
4. HAProxy termina TLS (certificado autofirmado), selecciona Web1 o Web2 mediante roundrobin y transmite internamente HTTP a 10.33.199.58:18081 o 10.33.199.62:18080.
5. El WordPress elegido procesa la petición. Para información de tienda usa MariaDB de VM279, 10.33.199.60:3306; para archivos cargados usa el montaje NFS de VM268.
6. La respuesta vuelve por HAProxy al cliente. El encabezado X-NodoSur-Backend permite comprobar qué backend respondió.

**Diferencia importante:** HTTP del proxy al backend es interno y no está cifrado de extremo a extremo por esta implementación. HTTPS protege el tramo cliente–HAProxy.

### Esquema

~~~text
Cliente (VPN/laboratorio)
    | DNS pregunta/respuesta a BIND9 VM268 :53
    | HTTPS :443 (o HTTP :80 => 301)
    v
VM308 HAProxy 10.33.195.194 / 10.33.199.61
    |           |
    | HTTP      | HTTP
    v           v
VM263 Web1    VM310 Web2
.58:18081     .62:18080
    | \         / |
    |  \       /  |
    |   \     /   |
    v    v   v    v
VM279 MariaDB   VM268 NFS
.60:3306        .59:2049
~~~

---

## 2. Inventario que deben conocer los cuatro

| VM | Hostname comprobado | Rol | SSH por VPN | IP interna | Puerto/servicio |
|---|---|---|---|---|---|
| 268 | nodosur-g7 | BIND9 + NFS + copias | 10.33.195.205 | 10.33.199.59 | DNS 53 UDP/TCP; NFS 2049 TCP |
| 263 | nodosurtas07 | Backend WordPress Web1 | 10.33.195.202 | 10.33.199.58 | HTTP 18081 |
| 310 | nodosur-g7-web2 | Backend WordPress Web2 | 10.33.195.208 | 10.33.199.62 | HTTP 18080 |
| 279 | svr-db-nodosur07 | MariaDB y datos | 10.33.195.226 | 10.33.199.60 | MariaDB 3306 |
| 308 | nodosur-g7-proxy | HAProxy + TLS | 10.33.195.194 | 10.33.199.61 | HTTP 80, HTTPS 443 |

La red interna es **10.33.199.56/29**: red .56, dirección .57 registrada como gateway, hosts .58–.62 usados por Nodo Sur y broadcast .63. Las direcciones 10.33.195.x corresponden al acceso/administración, **no** al enlace interno principal de los backends.

**Credenciales de revisión:** se creó la identidad Linux temporal tas_revision_e3 en las cinco VMs y se comprobó SSH+sudo. La cuenta antigua tas_revision quedó **caducada**, no borrada, en las tres VMs antiguas. El panel WordPress tiene administrador E3 separado, comprobado por HTTPS. **Las contraseñas se comparten solo por el canal privado acordado**; nunca se escriben en GitHub, la guía ni el chat. Conservar los HOME históricos porque algunas unidades systemd todavía apuntan allí.

**Entrar a un servidor:**

~~~bash
ssh tas_revision_e3@10.33.195.205  # VM268 DNS/NFS
ssh tas_revision_e3@10.33.195.202  # VM263 Web1
ssh tas_revision_e3@10.33.195.208  # VM310 Web2
ssh tas_revision_e3@10.33.195.226  # VM279 MariaDB
ssh tas_revision_e3@10.33.195.194  # VM308 HAProxy
~~~

Estos ejemplos son **cinco destinos alternativos**, no hay que abrirlos todos. Necesitan VPN/permiso. Si el profesor usa otra identidad, sustituir únicamente el usuario, nunca copiar claves a pantalla.

---

## 3. Rutas que pueden preguntar «¿dónde está?»

### 3.1 NFS: servidor, cliente y contenedor son TRES rutas distintas

| Lugar | Ruta real | Para qué |
|---|---|---|
| **VM268 servidor NFS** | /srv/nodosur/uploads | Directorio exportado que contiene archivos cargados |
| **VM263 y VM310, hosts Linux** | /srv/nodosur/nfs/uploads | Punto de montaje NFS del host cliente |
| **Dentro de ambos contenedores WordPress** | /var/www/html/wp-content/uploads | Directorio que usa WordPress/WooCommerce para archivos públicos |

La ruta dentro del contenedor es un **bind mount de la ruta NFS montada en el host**. Los datos viven originalmente en VM268. **NFS solo comparte uploads**; no se monta todo WordPress mediante NFS.

~~~bash
# VM268: servidor NFS. Ver qué exporta, sin modificarlo.
sudo exportfs -v
sudo ls -ld /srv/nodosur/uploads
sudo ls /srv/nodosur/uploads | head

# VM263 o VM310: cliente NFS.
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET,OPTIONS
ls -ld /srv/nodosur/nfs/uploads
ls /srv/nodosur/nfs/uploads | head

# VM263: origen del bind efectivo dentro del contenedor.
sudo docker inspect nodosur-web1 -f \
  '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'

# VM310: cambiar solo el nombre del contenedor.
sudo docker inspect nodosur-web2 -f \
  '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'

# Entrar al contenedor y mirar contenido del montaje (solo lectura).
sudo docker exec nodosur-web1 ls -lah /var/www/html/wp-content/uploads
~~~

**Qué responder si pregunta por una imagen:** «Primero miro /srv/nodosur/uploads en VM268, después verifico findmnt en las VMs web, y finalmente la misma ruta /var/www/html/wp-content/uploads dentro del contenedor. Si es el mismo archivo, comparo SHA-256. Ya está documentada una comparación de un placeholder de WooCommerce idéntica desde NFS, Web1 y Web2».

Archivo del ensayo productivo: woocommerce-placeholder-768x768.webp, huella de evidencia registrada:
bf0adb2caef65c6321690650203c488996f2f1c766bc9497ca25b171db1b4aa0.
No crear ni eliminar archivos productivos solamente para responder una pregunta.

### 3.2 Código WordPress, HTML y configuraciones

| Lugar | Web1 VM263 | Web2 VM310 |
|---|---|---|
| HTML WordPress en el **host** | /srv/nodosur/web1/html | /srv/nodosur/web2/html |
| Raíz del sitio **dentro del contenedor** | /var/www/html | /var/www/html |
| Plugins **dentro del contenedor** | /var/www/html/wp-content/plugins | Igual |
| Temas **dentro del contenedor** | /var/www/html/wp-content/themes | Igual |
| Core WordPress **dentro del contenedor** | /var/www/html/wp-admin y /var/www/html/wp-includes | Igual |
| Archivo sensible de configuración | /var/www/html/wp-config.php | Igual |
| Archivo público de configuración Apache en el host | /etc/nodosur/apache/nodosur-uploads.conf | Igual |
| Configuración Apache montada en contenedor | /etc/apache2/conf-enabled/nodosur-uploads.conf | Igual |

**Nunca mostrar el contenido de wp-config.php en una demo**: puede exponer secretos o salts. Sí se puede listar su existencia y entrar a directorios de código no sensible:

~~~bash
# VM263 / Web1 (lectura)
sudo ls -ld /srv/nodosur/web1/html
sudo ls /srv/nodosur/web1/html | head
sudo docker exec nodosur-web1 ls /var/www/html/wp-content
sudo docker exec nodosur-web1 ls /var/www/html/wp-content/plugins | head
sudo docker exec nodosur-web1 apache2ctl -t

# VM310 / Web2
sudo ls -ld /srv/nodosur/web2/html
sudo docker exec nodosur-web2 ls /var/www/html/wp-content/themes | head
sudo docker exec nodosur-web2 apache2ctl -t

# VM263/310: ver solo el archivo de protección Apache (sin secretos).
sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf
~~~

**Ojo con versiones:** el tag Docker productivo dice wordpress:7.1.2-php8.3-apache, pero el **core persistido** de ambos WordPress se comprobó en **7.1.3**. Esto es posible porque /var/www/html se conserva como bind mount. El 21/10 se alineó Web2 con respaldo y se comprobaron huellas coincidentes de 9.817 archivos de core/plugins/temas. No decir que la imagen sola garantiza reconstruir ese HTML 7.1.3.

**WordPress desde PHP (consulta sin mostrar credenciales):**

~~~bash
# VM263; en Web2 usar nodosur-web2.
sudo docker exec -u www-data nodosur-web1 php -r '
require "/var/www/html/wp-load.php";
global $wp_version;
echo "WP=" . $wp_version . "\n";
echo "SITEURL=" . get_option("siteurl") . "\n";
echo "HOME=" . get_option("home") . "\n";
'
~~~

### 3.3 Git, Compose, systemd: no son el mismo objeto

**Repositorio Git:** versiona archivos YAML, scripts, documentación y ejemplos sin secretos.

**Docker Compose:** describe contenedores/servicios, puertos, montajes y variables/archivos de secretos para el Docker Engine de **un host**.

**systemd:** mantiene el servicio de host que invoca Compose o supervisa dependencias. La unidad puede estar activa aunque el contenedor tenga un problema: consultar ambas capas.

| VM | Archivo Compose versionado | Contenedor Docker |
|---|---|---|
| Web1 VM263 | compose/web1/compose.yaml | nodosur-web1 |
| Web2 VM310 | compose/web2/compose.yaml | nodosur-web2 |
| DB VM279 | compose/db-stage/compose.prod.yaml | nodosur-db-staging |
| HAProxy VM308 | compose/proxy/compose.prod.yaml | nodosur-haproxy |
| DNS/NFS VM268 | No tiene Compose productivo de estas cuatro funciones | BIND9 y NFS nativos |

**No existe un solo Compose que cree las cinco VMs.** Los cuatro Compose están versionados en Git, pero **cada VM Docker tiene su propio proyecto y Docker Engine**. El proyecto e3-lab de Fedora fue un ensayo ficticio en un solo equipo y no sustituye las cinco VMs.

**Ubicación del checkout efectivamente usado:** las unidades systemd productivas consultadas usan un WorkingDirectory bajo **/home/USUARIO/nodosur-tas-grupo7**, no /opt/nodosur. En **Web1 y DB** se verificó específicamente **/home/tas_revision/nodosur-tas-grupo7**. Aunque la cuenta Linux tas_revision E2 está caducada, **no borrar su HOME**.

Para conocer la ruta real de una unidad, en vez de adivinar:

~~~bash
# VM263
sudo systemctl show nodosur-web1.service -p WorkingDirectory -p ActiveState -p UnitFileState
sudo systemctl cat nodosur-web1.service

# VM279
sudo systemctl show nodosur-db-prod.service -p WorkingDirectory -p ActiveState -p UnitFileState

# VM310, VM308: consultar el archivo de unidad antes de afirmar ruta.
sudo systemctl cat nodosur-web2.service
sudo systemctl cat nodosur-proxy.service
~~~

**Precaución:** los nombres de unidades anteriores derivan de archivos del repositorio; consultar con systemctl antes de asumir si están efectivamente instaladas con ese nombre en cada VM. Las unidades concretamente corroboradas son nodosur-web1.service, nodosur-db-prod.service y nodosur-db-stage.service.

**Ver Compose SIN levantar nada:**

~~~bash
# Ejecutar en la VM correspondiente y desde la carpeta correcta del repo.
# Comprobar primero: pwd y git status --short
sudo docker compose -f compose/web1/compose.yaml config --quiet
sudo docker compose -f compose/web2/compose.yaml config --quiet
sudo docker compose -f compose/db-stage/compose.prod.yaml config --quiet
sudo docker compose -f compose/proxy/compose.prod.yaml config --quiet
~~~

Esos cuatro comandos son **alternativas por rol**: no ejecutar los cuatro en una misma VM. Si se está fuera del repositorio, consultar WorkingDirectory y usar la ruta completa del archivo Compose. Evitar imprimir la salida completa de docker compose config si puede resolver variables privadas.

### 3.4 HAProxy: configuración y certificado

| Lugar | Ruta |
|---|---|
| YAML de despliegue de proxy (repositorio) | compose/proxy/compose.prod.yaml |
| Configuración versionada de HAProxy (repositorio) | compose/proxy/haproxy.prod.cfg |
| Configuración dentro del contenedor | /usr/local/etc/haproxy/haproxy.cfg |
| Certificado+clave privada en **VM308 host** | /etc/nodosur/tls/haproxy-www.pem |
| Ubicación del PEM dentro del contenedor | /usr/local/etc/haproxy/certs/haproxy.pem |

**No usar cat, sed ni copiar el PEM privado:** puede contener la clave privada TLS. El nombre del archivo basta para explicar el mount.

Dentro de haproxy.prod.cfg:
- Frontend escucha 8080 (HTTP) y 8443 (HTTPS dentro del contenedor).
- Redirección 301 a HTTPS.
- Balanceo roundrobin de web1 .58:18081 y web2 .62:18080.
- Encabezado de identificación X-NodoSur-Backend.
- Health check HEAD /, HTTP 200, inter 3s fall 3 rise 2.

### 3.5 MariaDB: volumen persistente

El contenedor en VM279 se llama **nodosur-db-staging** por herencia histórica, aunque atiende al sitio de E3. Base de datos conocida: **nodo_sur_final**.

El volumen Docker productivo **nodosur-db-staging_db_stage_data** está montado en **/var/lib/mysql dentro del contenedor**. No confundir nombre del volumen con una DB descartable.

~~~bash
# VM279: consulta de estado, no lectura de tablas privadas
sudo docker inspect --type container nodosur-db-staging \
  -f 'Estado={{.State.Status}} Salud={{.State.Health.Status}}'

sudo docker inspect --type container nodosur-db-staging \
  -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}Volumen={{.Name}} -> {{.Destination}}{{end}}{{end}}'

sudo docker volume ls --filter name=nodosur-db-staging_db_stage_data
~~~

**Nunca:** docker compose down -v, docker volume prune, borrar /var/lib/mysql, recrear DB sin respaldo ni copiar contraseñas SQL a comandos de demostración.

### 3.6 BIND9: zona DNS y registros

En **VM268**, la zona conocida es **nodosur07.tas**; el archivo de zona observado es **/etc/bind/db.nodosur07.tas** y la definición se consultó en **/etc/bind/named.conf.local**. BIND9 funciona en el **host**, no en un contenedor de este despliegue.

~~~bash
# VM268: comprobar sin modificar zona ni reiniciar DNS.
sudo named-checkconf -z
sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
sudo systemctl is-active bind9
sudo grep -n -A 8 -B 2 'zone "nodosur07.tas"' /etc/bind/named.conf.local

# Fedora con VPN: consultar el servidor autoritativo directamente.
dig @10.33.195.205 nodosur07.tas A +short
dig @10.33.195.205 nodosur07.tas SOA +noall +answer
dig @10.33.195.205 nodosur07.tas SOA +tcp +noall +answer
~~~

Se corrigió una exposición: anteriormente el servidor permitía AXFR desde Fedora por VPN; se instaló en la zona la restricción **allow-transfer { none; };** y una consulta posterior devolvió REFUSED sin dejar de responder SOA y A. No repetir transferencias completas ni modificar la zona para la evaluación.

---

## 4. Caja de herramientas del profesor: comando → qué muestra → qué NO demuestra

| Comando (en host correcto) | Lo que comprueba | Límite |
|---|---|---|
| hostname ; whoami ; pwd | Host, identidad y directorio actual | No indica rol de servicio automáticamente |
| ip -br addr | Interfaces e IPs presentes | Una IP no prueba conectividad |
| ip route | Rutas de red | No prueba aceptación por firewall |
| dig @10.33.195.205 nodosur07.tas A +short | Registro A servido por BIND9 | No prueba que HTTPS funcione |
| findmnt -M /srv/nodosur/nfs/uploads | NFS montado en la web | No comprueba por sí solo escritura |
| sudo exportfs -v (VM268) | Exports NFS anunciados | No prueba cómo lo ve cada cliente |
| sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | Contenedores actuales | Un running no garantiza app sana |
| sudo docker inspect -f '{{.State.Status}}' NOMBRE | Estado del contenedor concreto | No valida HTTP ni BD |
| sudo docker exec nodosur-web1 apache2ctl -t | Sintaxis Apache | No prueba toda la tienda |
| sudo docker exec nodosur-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg | Sintaxis del proxy | No prueba tráfico entrante |
| sudo systemctl is-active UNIDAD | Estado de unidad systemd | oneshot/RemainAfterExit puede estar active sin app sana |
| sudo iptables -S DOCKER-USER | Reglas de Docker en el host | No determina todas las rutas/firewalls |
| sudo iptables -nvL DOCKER-USER | Contadores y reglas | No atribuye cada paquete a un origen |
| sudo docker compose -f RUTA config --quiet | YAML Compose resoluble | No instala ni reconstruye servicios |
| sudo docker exec NOMBRE ls /var/www/html/wp-content | Directorios del WordPress | No revela configuración efectiva |
| curl -k -I https://nodosur07.tas/ | Respuesta cabeceras HTTPS sin validación de CA | -k no valida identidad del servidor |

**Diferencia comando vs verificación:** interpretar la salida y explicar la capa examinada es tan importante como recordar la sintaxis.

### Secuencia segura del recorrido HTTP desde Fedora

~~~bash
# VPN conectada. Nombre contra servidor DNS de Nodo Sur.
dig @10.33.195.205 nodosur07.tas A +short

# HTTP -> HTTPS: comprobar Location y estado.
curl --noproxy '*' -sSI --resolve nodosur07.tas:80:10.33.195.194 \
  http://nodosur07.tas/ | grep -Ei '^(HTTP/|location:)'

# HTTPS: inspeccionar estado y backend; -k NO valida el certificado.
curl --noproxy '*' -ksSI --resolve nodosur07.tas:443:10.33.195.194 \
  https://nodosur07.tas/ | grep -Ei '^(HTTP/|x-nodosur-backend:)'

# Repetir para observar el reparto (no asumir alternancia exacta si cambió salud).
for n in 1 2 3 4 5 6; do
  curl --noproxy '*' -ksSI --resolve nodosur07.tas:443:10.33.195.194 \
    https://nodosur07.tas/ | tr -d '\r' |
    grep -Ei '^(HTTP/|x-nodosur-backend:)'
done
~~~

### Secuencia desde VM308, el proxy autorizado hacia los backends

~~~bash
# VM308: comprobar proxy, health y backend directo.
sudo docker inspect --type container nodosur-haproxy \
  -f 'Estado={{.State.Status}}'
sudo docker exec nodosur-haproxy haproxy -c \
  -f /usr/local/etc/haproxy/haproxy.cfg

for destino in 10.33.199.58:18081 10.33.199.62:18080; do
  echo "BACKEND=$destino"
  curl --noproxy '*' --connect-timeout 5 --max-time 15 -sS \
    -o /dev/null -w 'HTTP=%{http_code}\n' \
    -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' \
    "http://$destino/"
done

# Logs acotados SOLO de DOWN / UP, sin imprimir requests/cookies.
sudo docker logs --since 30m nodosur-haproxy 2>&1 |
  grep -Ei 'Server backend_wordpress/web[12] is (DOWN|UP)' | tail -n 15
~~~

Las pruebas históricas registraron Web2 DOWN y 8/8 HTTP 200 servidos desde Web1 después de detección; tras recuperación, UP y 8/8 con reparto 4/4. **No detener un backend durante la evaluación salvo autorización explícita y plan de recuperación.**

### Comprobar seguridad en Web1 / Web2

~~~bash
# En cada VM web, lectura de política.
sudo systemctl is-active nodosur-docker-firewall.service
sudo iptables -S DOCKER-USER
sudo iptables -nvL DOCKER-USER

# Validar sintaxis Apache.
sudo docker exec nodosur-web1 apache2ctl -t
# En VM310 se usa nodosur-web2.

# Ver el bloqueo de PHP en uploads SIN subir PHP al sitio.
sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf
~~~

La regla DOCKER-USER de las webs bloquea accesos directos a los puertos internos desde orígenes distintos de 10.33.199.61 (proxy); la prueba diferencial observó HTTP 200 desde VM308 y timeout desde VM268. **HTTP=000 es una representación de curl cuando no recibió respuesta HTTP; no es un código del servidor.** El timeout no identifica por sí solo la regla exacta que lo causó.

### Usar validadores propios sin cambiar producción

~~~bash
# Fedora, clonado el repositorio actualizado:
bash scripts/validate-dns.sh

# Si se distribuyó un certificado público fiable para validarlo:
NODOSUR_CA_CERT=/ruta/certificado-publico.crt bash scripts/validate-web.sh

# Diagnóstico sin cadena de confianza válida (NO acredita identidad):
NODOSUR_INSECURE=1 bash scripts/validate-web.sh

python3 scripts/audit-secrets.py

# En VM del rol si el script y el checkout actualizado existen:
# NODOSUR_REPO_DIR=/ruta-real-del-repositorio bash scripts/preflight-e3.sh web1
# NODOSUR_REPO_DIR=/ruta-real-del-repositorio bash scripts/preflight-e3.sh web2
# NODOSUR_REPO_DIR=/ruta-real-del-repositorio bash scripts/preflight-e3.sh db
# NODOSUR_REPO_DIR=/ruta-real-del-repositorio bash scripts/preflight-e3.sh proxy
~~~

**Importante:** el repositorio de Fedora/GitHub está más actualizado que los checkouts productivos. **No asumir** que los scripts nuevos se encuentran en cada VM. Tampoco ejecutar git pull/reset/clean para «igualar» a última hora: Web1 y Web2 conservan cambios locales de Compose probados y se requiere preservarlos.

---

## 5. Los siete criterios de la rúbrica: prueba + cómo contestar

### A. Aplicación multicontenedor reproducible · 15 puntos

**Qué mostrar:** archivos Compose de cada host, docker compose config --quiet, rutas/montajes y guía de prerrequisitos. En Fedora se desplegó un proyecto independiente con MariaDB, dos WordPress y HAProxy, más una segunda prueba de arranque nuevo con dependencias automáticas; uploads-init finalizó Exited (0), permisos UID/GID 33:33, y escritura Web1/lectura Web2 con hashes iguales.

**Frase defendible:** «Reprodujimos desde cero la **capa Docker de ensayo** y documentamos cómo reproducir los roles del iLab; no reconstruimos automáticamente las cinco VMs ni restauramos datos reales. Cada Compose necesita que el host, la red, el NFS, los secretos y los bind mounts estén preparados».

**Riesgo que podría observar el profesor:** Web1/Web2 declaran imagen 7.1.2 pero contenido WordPress persistente 7.1.3; y el ensamble completo de BIND/NFS/TLS/secretos externos no se reensayó desde cero. Para 15/15 explicar la diferencia sin esconderla. Si aplica nivel 80/12, es una interpretación posible, no que el ensayo haya fallado.

### B. Dos backends funcionales · 15 puntos

**Qué mostrar:** nodosur-web1 y nodosur-web2 running, raíz/tienda/imágenes HTTP 200, encabezado que identifica servidor, versiones 7.1.3 en ambos y 9.817 ficheros auditados iguales.

**Explicación:** «Son dos VMs con sus propios Docker WordPress. No dependen entre sí como procesos, pero ambos dependen de MariaDB y NFS compartidos. No decimos que todos los aspectos de sus sesiones sean idénticos».

### C. HAProxy, TLS y health checks · 20 puntos

**Qué mostrar:** HAProxy config test válido, HTTPS, redirección 301, X-NodoSur-Backend y evidencias de DOWN/UP.

**Explicación:** «HAProxy termina TLS, hace roundrobin y retira/reintegra webs según un HEAD / con respuesta 200; intervalos inter 3s fall 3 rise 2. Esa verificación no simula una compra completa».

### D. Persistencia y coherencia del estado · 15 puntos

**Qué mostrar:** DB compartida y volumen histórico, NFS entre webs, SHA-256 de un archivo, carrito WooCommerce observado en distintos backends y ensayo Fedora de persistencia tras reinicio.

**Explicación:** «Una sola DB evita productos/pedidos divergentes entre las webs y NFS evita archivos de uploads distintos. La desventaja es que ambas dependencias son SPOF. No probamos compras concurrentes ni todas las sesiones».

### E. Segmentación, firewall y secretos · 15 puntos

**Qué mostrar:** DOCKER-USER, matriz de flujos, prueba origen permitido vs bloqueado, archivos sensibles fuera del repo, protección de PHP en uploads, renovación de cuentas de revisión E3.

**Explicación:** «Solo HAProxy debería llegar directamente a los puertos web internos; probamos HTTP 200 desde proxy y timeout desde otro host. Verificamos secretos fuera de Git y bloqueamos scripts PHP en uploads. Una auditoría heurística no equivale a garantizar cero secretos».

### F. Falla y recuperación · 15 puntos

**Qué mostrar:** evidencia histórica de detención Web2, log DOWN, 8 solicitudes HTTP 200 atendidas por Web1 y luego UP con reparto 4/4.

**Explicación:** «Probamos continuidad **después de detectar la caída** de un backend. No afirmamos que ninguna solicitud fallara durante la ventana de detección; tampoco medimos RTO/RPO».

### G. Análisis de disponibilidad y documentación · 5 puntos

**Explicación:** «Balancear dos backends no hace que toda la plataforma sea HA. HAProxy, MariaDB, DNS y NFS son puntos únicos de falla. Necesitaríamos componentes redundantes, replicación/recuperación y pruebas para evolucionar».

**Documento de respaldo:** [rúbrica original contrastada y autoevaluación](RUBRICA-E3.md). La nota final solo la otorga el profesor.

---

## 6. Preguntas sorpresa con respuestas modelo

### Arquitectura y redes

**1. ¿Para qué sirve DNS?** Devuelve la dirección asociada al dominio; el navegador luego conecta al proxy. No transporta solicitudes WordPress.

**2. ¿Por qué no apunta el dominio directamente a Web1?** Porque HAProxy es el punto de entrada único que reparte tráfico y puede retirar un backend que falla.

**3. ¿Qué hace HAProxy realmente?** Recibe HTTP/HTTPS, redirige a HTTPS, termina TLS, consulta salud y envía peticiones a un backend según roundrobin.

**4. ¿Cuál es la diferencia entre IP de gestión e IP interna?** Las 10.33.195.x son rutas de acceso/administración y publicación del proxy; la red 10.33.199.56/29 conecta servicios internos.

**5. ¿Por qué hay cuatro Compose si son cinco VMs?** Porque DNS/NFS están instalados como servicios nativos de VM268. Los otros cuatro hosts ejecutan los contenedores de sus roles.

**6. ¿Docker Compose crea VMs?** No; administra servicios/contendores de un motor Docker. Crear VMs y configurar red requiere provisión externa.

**7. ¿Qué pasa con el puerto 443?** El cliente llega a 10.33.195.194:443; Docker lo publica al 8443 de HAProxy y allí se maneja TLS.

**8. ¿Por qué las webs reciben HTTP y no HTTPS?** HAProxy termina TLS y habla HTTP por la red interna. Es una decisión del laboratorio y un límite de cifrado.

**9. ¿Qué significa /29?** Prefijo IPv4 de 29 bits, ocho direcciones totales; en esta red .56 identifica red y .63 broadcast. No confundir direcciones de red/gateway con las cinco IPs de hosts.

**10. ¿Cómo se sabe cuál backend atendió?** Consultando X-NodoSur-Backend en las respuestas del proxy o sus logs filtrados.

### Docker, Compose y contenedores

**11. Diferencia entre imagen y contenedor.** Imagen: plantilla inmutable referenciada por tag/digest; contenedor: proceso/instancia creada a partir de ella. Volúmenes/bind mounts aportan persistencia externa.

**12. Diferencia entre volumen Docker y bind mount.** Volumen: almacenamiento administrado por Docker, como la DB. Bind mount: mapea una ruta explícita del host, como HTML y NFS uploads de WordPress.

**13. ¿Qué hace docker compose config --quiet?** Comprueba que Compose puede resolver la definición sin imprimir la configuración. No arranca ni prueba la aplicación.

**14. ¿Qué hace docker exec?** Ejecuta un comando dentro de un contenedor existente; por ejemplo ls en uploads o apache2ctl -t. No es lo mismo que entrar al host por SSH.

**15. ¿Dónde está el código WordPress?** En los directorios HTML de los hosts web, montados como /var/www/html en cada contenedor. NO en la carpeta NFS completa: NFS solo contiene uploads.

**16. ¿Por qué el tag 7.1.2 y WordPress indica 7.1.3?** El HTML queda persistido en el host y se actualizó; la imagen declarada permanece con tag 7.1.2. Reproducir exige provisionar el mismo contenido persistido.

**17. ¿Qué son las redes de Compose?** Redes que conectan contenedores en un motor; no crean por sí mismas VLAN ni redes entre cinco VMs físicas/virtuales.

**18. ¿Qué significa restart: "no"?** Docker no reinicia automáticamente ese contenedor por esa política. Las unidades systemd pueden intervenir en el arranque, pero su estado active no garantiza contenedor healthy.

**19. ¿Qué hace uploads-init?** En el ensayo Fedora inicializa permisos de la raíz de un volumen ficticio como UID/GID 33 para www-data y termina con estado 0 antes de que arranquen las webs. No está desplegado como contenedor adicional en el iLab productivo.

### NFS, datos y aplicación

**20. ¿En qué máquina vive el archivo NFS?** En VM268 bajo /srv/nodosur/uploads. Las webs lo montan en /srv/nodosur/nfs/uploads; dentro del WordPress se ve /var/www/html/wp-content/uploads.

**21. ¿Por qué compartir solo uploads?** Para que las imágenes sean iguales al cambiar de backend. Core/plugins/temas y wp-config.php siguen locales, y por eso hay que mantenerlos coherentes aparte.

**22. ¿Cómo probamos que era el mismo archivo?** Se calculó SHA-256 del archivo original en NFS y del contenido HTTP servido desde Web1 y Web2; coincidieron. El ensayo nuevo local mostró escritura/lectura cruzada también, con otro hash.

**23. ¿Dónde guarda los productos WooCommerce?** La información estructurada está en MariaDB común; los archivos subidos, en uploads NFS. No confundir registros SQL con imágenes.

**24. ¿Por qué la DB se llama nodosur-db-staging?** Nombre histórico del proyecto/contendor. En E3 sigue siendo el volumen con datos que atienden a nodo_sur_final; cambiar el proyecto puede crear otra DB vacía.

**25. ¿Cómo inspecciono persistencia sin editar?** docker inspect del montaje /var/lib/mysql en VM279; findmnt en webs; hashes de archivos de prueba ya registrados. No hace falta ejecutar INSERT, DROP o restaurar.

**26. ¿Qué no probamos de sesiones?** No todas las sesiones privadas, salts y compras concurrentes. La evidencia de un carrito entre backends no equivale a validar todos esos escenarios.

### Seguridad y disponibilidad

**27. ¿Para qué sirve DOCKER-USER?** Permite aplicar filtros a tráfico hacia contenedores en el host Docker antes del flujo normal de reglas Docker. En los dos backends se restringió el puerto interno a origen proxy.

**28. ¿Qué indica un timeout desde VM268?** No se completó conexión HTTP en el tiempo dado; combinado con acceso permitido desde VM308 respalda segmentación por origen, pero no demuestra por sí solo qué regla bloqueó cada paquete.

**29. ¿Qué evita el archivo Apache de uploads?** Que archivos PHP/CGI subidos se ejecuten desde el directorio de datos compartidos; también evita listado de directorio según la regla configurada.

**30. ¿Por qué sale «no seguro» el certificado?** Es autofirmado; cifra TLS pero no tiene confianza automática de una CA reconocida. curl -k omite validación de identidad.

**31. ¿Dónde guardamos contraseñas?** En archivos externos al repositorio, protegidos por permisos, y se entregan al docente por canal privado. Nunca abrir su contenido para mostrar evidencia.

**32. ¿Qué es un SPOF?** Un componente sin redundancia cuya caída puede interrumpir el servicio. Aquí HAProxy, MariaDB y NFS/DNS únicos siguen siendo SPOF.

**33. ¿Qué distingue balanceo, tolerancia a fallas y HA integral?** Balanceo distribuye peticiones; tolerancia probada significa que otro backend atiende ante un fallo particular; HA integral requiere eliminar y probar los puntos únicos de falla relevantes.

**34. ¿Qué hace fall 3/rise 2?** HAProxy espera tres chequeos fallidos para marcar DOWN y dos correctos para reintegrar. El intervalo 3s no es por sí mismo una medida de RTO.

**35. ¿Qué pasa si HAProxy cae?** Aunque ambas webs estén sanas, el cliente pierde su punto de entrada; nuestra solución no tiene otro proxy automático.

**36. ¿Qué pasa si falla VM268?** Se afectan BIND9 y el servidor NFS de uploads; dos funciones críticas concentradas en un host.

**37. ¿Qué pasa si falla MariaDB?** Los dos WordPress comparten esa dependencia; no garantizamos continuidad de la tienda ante su caída.

**38. ¿Por qué no probar otra falla ahora?** Ya existe evidencia controlada DOWN/UP con recuperación; una nueva interrupción productiva necesita ventana, autorización y plan de reversión, no se improvisa.

**39. ¿Qué demuestra systemctl active?** Solo el estado de esa unidad. Una unidad oneshot puede quedar activa mientras un contenedor posterior falla; contrastamos Docker y HTTP.

**40. ¿Dónde están las credenciales E3?** En el canal privado del grupo/docente, nunca GitHub. Se renovó el acceso docente Linux a cinco VMs y se retiraron privilegios administrativos WordPress E2; el HOME E2 se preservó por dependencias systemd.

---

## 7. Si el profesor plantea un error: orden de diagnóstico por capas

No comenzar reiniciando ni modificando reglas. **Definir síntoma, mostrar evidencia y aislar la capa afectada**:

| Capa | Pregunta | Comprobación inicial |
|---|---|---|
| Nombre | ¿nodosur07.tas resuelve? | dig @10.33.195.205 ... A |
| Ruta | ¿llego a la red correcta? | ip route ; ip -br addr ; ping solo si autorizado |
| Puerto | ¿conecta :443, :18080/18081 o :3306 desde origen permitido? | curl con --connect-timeout, ss -lnt; comparar origen |
| TLS | ¿se establece HTTPS? ¿se confía en certificado? | curl -I y diagnóstico -k acotado |
| HTTP / proxy | ¿301? ¿200? ¿quién atendió? | curl -D - y X-NodoSur-Backend |
| Aplicación | ¿Apache/WordPress responden? | docker ps, apache2ctl -t, ruta /tienda/ |
| Dependencias | ¿DB saludable? ¿NFS montado? | docker inspect health; findmnt; SHA |
| Configuración | ¿archivo instalado equivale a repo y unidad? | Compose config --quiet, systemctl cat, comparación de huella |
| Recuperación | ¿qué acción mínima sería reversible? | Plantear hipótesis, respaldo/ventana, aprobación antes de ejecutar |

**Ejemplos de respuesta breve:**

- «Si DNS falla pero curl --resolve funciona, probablemente debo revisar resolución antes que HAProxy».
- «Si HTTP 200 solo viene de Web1, revisaré salud de Web2 y logs DOWN/UP del proxy; no asumiré que roundrobin está roto».
- «Si una imagen aparece en Web1 pero no Web2, revisaré findmnt, mounts Docker, el archivo de NFS y sus hashes; no copiaré carpetas sin comprobar cuál es la fuente de verdad».
- «Si systemd dice active pero la tienda cae, consultaré docker inspect y luego HTTP; el estado de systemd no es suficiente».
- «Si MariaDB figura healthy pero el carrito falla, una comprobación de health no prueba todo el flujo de negocio».

---

## 8. Preparación por integrante, sin exposición formal

El profesor puede elegir **cualquier integrante**. Todos deben poder hacer el recorrido completo. Practiquen de forma rotativa: una persona hace de profesor, otra responde, una tercera observa comandos/resultado y la cuarta cuestiona el límite. Intercambien roles hasta que todos puedan responder.

**Prueba individual mínima (sin modificar nada):**

- [ ] Dibujar de memoria las cinco VMs, los roles y el flujo DNS → HAProxy → WordPress → DB/NFS.
- [ ] Localizar en la máquina correcta el Compose, el contenedor y la unidad systemd.
- [ ] Mostrar exactamente de dónde viene y dónde se monta NFS, sin confundir host/cliente/contenedor.
- [ ] Explicar la diferencia entre imagen 7.1.2 y WordPress persistido 7.1.3.
- [ ] Comprobar DNS A, HTTPS 200/301 y el backend que atendió.
- [ ] Mostrar health MariaDB y nombre del volumen que NO se debe borrar.
- [ ] Validar sintaxis Apache/HAProxy y reconocer qué no asegura cada chequeo.
- [ ] Explicar DOCKER-USER y por qué la prueba negativa no prueba una regla específica por sí sola.
- [ ] Describir el evento histórico DOWN → continuidad → UP sin detener producción.
- [ ] Identificar todos los SPOF sin usar «HA integral».
- [ ] Defender la reproducibilidad del proyecto aislado Fedora, declarando la provisión externa de las cinco VMs.

**Comandos que NO deben improvisarse durante la evaluación:** docker compose down -v, docker volume prune, git reset --hard, git clean, borrado de HOME antiguos, edición de wp-config.php, exposición del PEM TLS, cambios de iptables/ufw/named.conf, reinicios de DB/NFS/proxy o parada de un backend sin autorización.

**Qué documentación abrir primero:**
1. [Arquitectura con diagrama](../ARQUITECTURA.md).
2. [Inventario real de VMs](../INVENTARIO.md).
3. [Plan de comandos de demostración](PLAN-DEMOSTRACION-E3.md).
4. [Pruebas y límites por criterio](RUBRICA-E3.md).
5. [Ensayo de reproducibilidad](ENSAYO-REPRODUCIBILIDAD-E3.md).
6. [Matriz de flujos de red](MATRIZ-FLUJOS-E3.md).
7. [Mapa de archivos, reglas y rutas](MAPA-CONFIGURACIONES-E3.md): **qué archivo se modifica y qué comando lo demuestra**.
8. [Accesos temporales de revisión](ACCESO-DOCENTE-E3.md), **sin secretos**.
9. [Evidencia completa de E3](../evidencias/README.md).

---

## 9. Pregunta para el profesor después de E3: automatizar cinco VMs

Propuesta de pregunta breve y pertinente, **fuera de la calificación actual**:

> «Profe, para aprender más después de esta entrega queremos automatizar una infraestructura como Nodo Sur, no solo los contenedores. ¿El iLab permite aprovisionar máquinas con plantillas o API, o solo administrarlas? ¿Tendría sentido combinar infraestructura como código para crear las VMs, cloud-init para el inicio y Ansible para configurar BIND, NFS, Docker y Compose?».

**Qué es cada pieza a nivel conceptual:**
- **Terraform/OpenTofu:** definir y crear recursos de infraestructura cuando el hipervisor/nube tenga proveedor y permisos adecuados. **No asumir que el iLab permite crear VMs por API** hasta preguntarlo.
- **cloud-init:** configuración inicial del sistema operativo si la imagen/plantilla lo soporta.
- **Ansible:** preparar usuarios, paquetes, NFS, BIND9, firewall y desplegar definiciones Compose por cada host con orden y comprobaciones.
- **Docker Compose:** crea/gestiona **contenedores en un host Docker**, no cinco máquinas virtuales.

Este tema es un **proyecto posterior a E3**; no ampliar alcance ni arriesgar las VMs antes de la evaluación.

---

**Idea final para los cuatro:** no basta con decir «funciona». Cada respuesta debe conectar **componente → ruta/comando → evidencia observable → límite conocido**. Si no recuerdan algo, es preferible ubicarlo y demostrarlo en la terminal de forma segura antes que inventarlo.
