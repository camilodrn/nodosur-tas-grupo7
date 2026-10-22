# Mapa de archivos, reglas y carpetas — Nodo Sur E3

**Para la revisión individual del profesor · 22/10/2026**

[Guía de estudio](GUIA-ESTUDIO-INDIVIDUAL-E3.md) · [Tarjeta de comandos](TARJETA-COMANDOS-E3.md) · [Inventario de VMs](../INVENTARIO.md)

## Antes de responder «¿qué archivo modificaron?»

Hay que distinguir tres conceptos:

- **Archivo del repositorio:** configuración versionada en Git; no demuestra por sí solo lo que se ejecuta en la VM.
- **Archivo instalado en el host o contenedor:** configuración que lee realmente el servicio.
- **Estado efectivo:** servicio, regla o montaje verificado con comandos como systemctl cat, iptables -S, findmnt, docker inspect, exportfs -v y validadores de sintaxis.

Marcamos **COMPROBADO** cuando existe evidencia de ruta/estado del iLab; **REFERENCIA GIT** para archivos versionados; y **POR CONFIRMAR** cuando la transcripción no identifica el archivo exacto instalado.

## 1. Mapa de configuración: servidor, archivo y cómo mostrarlo

| Componente | Archivo o ruta | Qué contiene o qué se modificó | Cómo comprobar sin cambiar nada | Evidencia |
|---|---|---|---|---|
| **VM268 BIND9** | **/etc/bind/named.conf.local** | Zona nodosur07.tas. **Se añadió allow-transfer { none; };** para negar AXFR. | sudo grep -n -A 8 -B 2 'zone "nodosur07.tas"' /etc/bind/named.conf.local | **COMPROBADO** 21/10 |
| **VM268 zona DNS** | **/etc/bind/db.nodosur07.tas** | Registros DNS de la zona. La restricción AXFR **no** se colocó en el archivo de registros. | sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas | Ruta **COMPROBADA** |
| **VM268 NFS servidor** | **/srv/nodosur/uploads** | Directorio de imágenes/archivos que se exporta. **Es carpeta de datos, no el archivo de configuración NFS.** | sudo exportfs -v; sudo ls -ld /srv/nodosur/uploads | **COMPROBADO** |
| **VM268 NFS configuración** | Posibles **/etc/exports** o **/etc/exports.d/*.exports** | Reglas de exportación y clientes. **No quedó identificado cuál archivo exacto se editó en el iLab.** | Consultas detalladas de la sección NFS | **POR CONFIRMAR** |
| **VM263/310 montaje NFS del host** | **/srv/nodosur/nfs/uploads** | Carpeta del host que monta el export 10.33.199.59:/srv/nodosur/uploads. | findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET,OPTIONS | **COMPROBADO** |
| **VM263/310 persistencia del montaje** | Posibles **/etc/fstab** o unidad **.mount** systemd | Define cómo montar NFS al arrancar; el archivo exacto utilizado **no fue registrado**. | Consultas de la sección NFS | **POR CONFIRMAR** |
| **VM263 código WordPress Web1** | **/srv/nodosur/web1/html** | Árbol persistente del WordPress instalado. | sudo ls -lah /srv/nodosur/web1/html | **COMPROBADO** |
| **VM310 código WordPress Web2** | **/srv/nodosur/web2/html** | Otro árbol persistente de WordPress. | sudo ls -lah /srv/nodosur/web2/html | **COMPROBADO** |
| **Dentro de ambos WordPress** | **/var/www/html** | Ruta interior de código; plugins en wp-content/plugins, temas en wp-content/themes. | sudo docker exec NOMBRE ls /var/www/html/wp-content | **COMPROBADO** |
| **Dentro de ambos WordPress** | **/var/www/html/wp-content/uploads** | **Solo esta carpeta** viene de NFS montado en el host web. | docker inspect limitado a .Mounts | **COMPROBADO** |
| **VM263/310 Apache seguridad** | **/etc/nodosur/apache/nodosur-uploads.conf** | Regla activa que bloquea PHP/PHTML/PHAR/CGI y listado en uploads. | sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf | **COMPROBADO en ambos** |
| **Apache dentro del contenedor** | **/etc/apache2/conf-enabled/nodosur-uploads.conf** | Bind mount de solo lectura del archivo anterior. | sudo docker exec NOMBRE apache2ctl -t; docker inspect montajes | **COMPROBADO** |
| **Git: regla Apache** | **configs/apache/nodosur-uploads.conf** | Copia versionada de la protección anterior. | sed -n '1,80p' configs/apache/nodosur-uploads.conf | **REFERENCIA GIT y desplegada** |
| **Git: Compose Web1** | **compose/web1/compose.yaml** | Contenedor, imagen, 18081 y montajes HTML/NFS/Apache. | sudo docker compose -f compose/web1/compose.yaml config --quiet desde su checkout en VM263 | **COMPROBADO en VM263** |
| **Git: Compose Web2** | **compose/web2/compose.yaml** | Contenedor, imagen, 18080, montajes, SQL y secreto externo. | sudo docker compose -f compose/web2/compose.yaml config --quiet desde su checkout en VM310 | **COMPROBADO en VM310** |
| **Git: Compose MariaDB** | **compose/db-stage/compose.prod.yaml** | MariaDB 10.11, puerto 3306, volumen y secreto. | sudo docker compose -f compose/db-stage/compose.prod.yaml config --quiet en VM279 | **COMPROBADO en VM279** |
| **DB productiva** | **Volumen nodosur-db-staging_db_stage_data** → **/var/lib/mysql** | Datos de la tienda. Conserva nombre histórico staging. | sudo docker inspect nodosur-db-staging -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}' | **COMPROBADO** |
| **Git: Compose proxy** | **compose/proxy/compose.prod.yaml** | Publicación HTTP/HTTPS y binds de configuración/certificado. | sudo docker compose -f compose/proxy/compose.prod.yaml config --quiet en VM308 | **COMPROBADO en VM308** |
| **Git: HAProxy configuración** | **compose/proxy/haproxy.prod.cfg** | Redirección HTTPS, roundrobin, health check HEAD /, X-NodoSur-Backend. | sed -n '1,100p' compose/proxy/haproxy.prod.cfg | **REFERENCIA GIT** |
| **HAProxy contenedor** | **/usr/local/etc/haproxy/haproxy.cfg** | Configuración instalada y validada por haproxy -c. | sudo docker exec nodosur-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg | **COMPROBADO** |
| **Firewall Web1/Web2** | **Cadena DOCKER-USER efectiva del kernel** | Reglas iptables que restringen origen hacia los puertos internos a IP del proxy 10.33.199.61. | sudo iptables -S DOCKER-USER; sudo iptables -nvL DOCKER-USER | **COMPROBADO** |
| **Firewall servicio Web1/Web2** | **nodosur-docker-firewall.service** | Servicio systemd activo; el **script exacto ejecutado** se identifica en ExecStart. | sudo systemctl cat nodosur-docker-firewall.service | Servicio **COMPROBADO**; script exacto **POR CONFIRMAR** |
| **Git: plantilla firewall webs** | **configs/firewall/nodosur-docker-firewall.sh** | Lógica versionada de iptables y proxy permitido; comprobar si corresponde a script instalado. | sed -n '1,100p' configs/firewall/nodosur-docker-firewall.sh | **REFERENCIA GIT** |
| **Firewall DB VM279** | **DOCKER-USER y UFW efectivos** | Excepciones observadas a 3306 desde web1 .58 y web2 .62; existe otra excepción .59 de propósito no confirmado. | sudo iptables -S DOCKER-USER; sudo ufw status numbered | **COMPROBADO**; archivo exacto de reglas **POR CONFIRMAR** |
| **Web1 systemd** | **nodosur-web1.service**; Git: **configs/systemd/nodosur-web1.service** | Usa WorkingDirectory /home/tas_revision/nodosur-tas-grupo7; invoca Compose del backend. | sudo systemctl cat nodosur-web1.service; sudo systemctl show nodosur-web1.service -p WorkingDirectory | **COMPROBADO** |
| **MariaDB systemd** | **nodosur-db-prod.service**; Git: **configs/systemd/nodosur-db-prod.service** | Usa WorkingDirectory /home/tas_revision/nodosur-tas-grupo7. | sudo systemctl cat nodosur-db-prod.service | **COMPROBADO** |
| **Web2/proxy systemd** | **configs/systemd/nodosur-web2.service** y **configs/systemd/nodosur-proxy.service** | Archivos Git. Confirmar **nombre y ubicación de la unidad realmente cargada** antes de afirmarlo. | systemctl list-unit-files 'nodosur*'; sudo systemctl cat NOMBRE_REAL | **REFERENCIA GIT; instalación POR CONFIRMAR** |
| **Secretos WordPress** | **/var/www/html/wp-config.php** | Configuración de aplicación y credenciales. | sudo docker exec NOMBRE test -f /var/www/html/wp-config.php && echo EXISTE | **PRIVADO, NO IMPRIMIR** |
| **Secreto SQL DB VM279** | **/etc/nodosur/secrets/db-stage-root.password** | Archivo externo al repositorio. | sudo test -s /etc/nodosur/secrets/db-stage-root.password && echo PRESENTE | **PRIVADO** |
| **Secreto SQL Web2 VM310** | **/etc/nodosur/secrets/cms_web62.password** | Archivo externo al repositorio. | sudo test -s /etc/nodosur/secrets/cms_web62.password && echo PRESENTE | **PRIVADO** |
| **TLS VM308** | **/etc/nodosur/tls/haproxy-www.pem** | Certificado **más clave privada** que lee HAProxy. | sudo test -s /etc/nodosur/tls/haproxy-www.pem && echo PRESENTE | **PRIVADO, NO CAT** |

**Los cuatro comandos Compose son alternativas por VM, no se ejecutan todos en una sola máquina.** La integración Git en main no significa que todas las VMs hayan actualizado su checkout; Web1/Web2 mantienen cambios locales de Compose que fueron validados y se deben conservar.

---

## 2. Pregunta NFS: «¿qué carpeta y qué archivo modificaron?»

**Respuesta segura:** «VM268 es el servidor NFS y exporta /srv/nodosur/uploads. Web1 y Web2 montan ese export en /srv/nodosur/nfs/uploads. El WordPress de cada contenedor ve los archivos en /var/www/html/wp-content/uploads. La conexión entre la carpeta host y el contenedor se declara en compose/web1/compose.yaml y compose/web2/compose.yaml. Para mostrar el archivo exacto de las reglas del servidor NFS, consulto el export activo y luego dónde está declarado».

**VM268: localizar export y archivo fuente sin editar:**

~~~bash
sudo exportfs -v

if [ -f /etc/exports ]; then
  sudo grep -nF '/srv/nodosur/uploads' /etc/exports || true
fi

if [ -d /etc/exports.d ]; then
  sudo grep -RnsF '/srv/nodosur/uploads' /etc/exports.d || true
fi

sudo ls -ld /srv/nodosur/uploads
~~~

**Web1 o Web2: localizar dónde se monta:**

~~~bash
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET,OPTIONS

if [ -f /etc/fstab ]; then
  grep -nF '/srv/nodosur/nfs/uploads' /etc/fstab || true
fi

systemctl list-units --type=mount --all --no-pager |
  grep -F 'nodosur' || true
~~~

**Importante:** /etc/exports, /etc/exports.d y /etc/fstab son **lugares habituales** de configuración, pero las evidencias aportadas **no permiten afirmar cuál de ellos modificó el grupo**. Si el profesor lo pregunta, se demuestra en la VM. No confundir archivo de configuración del export con carpeta exportada.

**El código comprobado en los Compose web es:**

~~~yaml
volumes:
  - type: bind
    source: /srv/nodosur/nfs/uploads
    target: /var/www/html/wp-content/uploads
    bind:
      create_host_path: false
~~~

El **source** pertenece al Linux del host web, el **target** es la ruta dentro del contenedor, y **create_host_path: false** evita que Docker cree silenciosamente ese directorio si falta. **Compose no crea la VM268, ni configura por sí mismo el servidor NFS o el montaje Linux previo.**

---

## 3. Pregunta Apache: «¿dónde está la regla de seguridad?»

**Respuesta:** «En Git está configs/apache/nodosur-uploads.conf. Lo instalamos en /etc/nodosur/apache/nodosur-uploads.conf tanto en Web1 como en Web2. Compose lo monta de solo lectura en /etc/apache2/conf-enabled/nodosur-uploads.conf dentro de WordPress».

**Regla versionada:**

~~~apache
<Directory /var/www/html/wp-content/uploads>
    AllowOverride None
    Options -ExecCGI -Indexes
    <FilesMatch "\.(?i:php[0-9]?|phtml|phar)(?:\.|$)">
        Require all denied
    </FilesMatch>
</Directory>
~~~

**En VM263 o VM310:**

~~~bash
sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf
sudo docker exec nodosur-web1 apache2ctl -t

sudo docker inspect nodosur-web1 -f \
  '{{range .Mounts}}{{if eq .Destination "/etc/apache2/conf-enabled/nodosur-uploads.conf"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'
~~~

En Web2 reemplazar nodosur-web1 por nodosur-web2. Evidencia histórica: portada, tienda e imagen HTTP 200; ruta PHP inexistente bajo uploads HTTP 403 en **ambas** webs. Se probó también un PHP inocuo **existente en contenedor aislado**, no en producción.

---

## 4. Pregunta BIND9: «¿qué archivo se tocó para AXFR?»

**Respuesta:** «El cambio se hizo en /etc/bind/named.conf.local dentro de la zona nodosur07.tas, añadiendo allow-transfer { none; };. El archivo de registros de la zona es /etc/bind/db.nodosur07.tas, pero la ACL de transferencia se puso en named.conf.local».

~~~bash
# VM268: consultar bloque de zona y validar la configuración.
sudo grep -n -A 8 -B 2 'zone "nodosur07.tas"' /etc/bind/named.conf.local
sudo named-checkconf -z
sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas

# Fedora por VPN: verificar el servicio DNS sin cambiarlo.
dig @10.33.195.205 nodosur07.tas A +short
~~~

Resultado registrado: AXFR desde Fedora VPN pasó de permitir nueve registros a **REFUSED**; SOA UDP/TCP y registro A siguieron funcionando. No volver a abrir la transferencia para mostrarla.

---

## 5. Pregunta firewall: «¿qué archivo tiene las reglas?»

**Respuesta:** «En el host Web1 o Web2, la política efectiva está en iptables, cadena DOCKER-USER. El servicio nodosur-docker-firewall.service la mantiene. Para ubicar el script que realmente carga las reglas reviso systemctl cat y ExecStart. En Git tenemos una plantilla de referencia en configs/firewall/nodosur-docker-firewall.sh, pero no doy por hecho que la VM ejecuta exactamente ese archivo hasta compararlo».

~~~bash
# VM263 o VM310. Solo consultas.
sudo systemctl cat nodosur-docker-firewall.service
sudo systemctl show nodosur-docker-firewall.service -p ExecStart
sudo iptables -S DOCKER-USER
sudo iptables -nvL DOCKER-USER
~~~

**Fragmento del código versionado (no sustituye regla activa):**

~~~sh
PROXY="10.33.199.61"
iptables -C DOCKER-USER \
  -p tcp -m conntrack --ctdir ORIGINAL \
  --ctorigdst "$IP" --ctorigdstport "$PORT" \
  ! -s "$PROXY" -j DROP
~~~

La prueba documentada observó HTTP 200 desde VM308 hacia Web1/Web2 y timeout desde VM268 hacia sus puertos internos. El timeout **no indica cuál regla exacta hizo DROP** sin correlación adicional. En MariaDB existen también reglas DOCKER-USER y UFW, revisadas por separado.

---

## 6. Pregunta HAProxy: «¿dónde está el código del balanceo?»

**En Git:** compose/proxy/haproxy.prod.cfg. **En el contenedor:** /usr/local/etc/haproxy/haproxy.cfg. **El archivo de Compose** compose/proxy/compose.prod.yaml monta el anterior. El certificado con clave privada está **fuera de Git** y **no debe imprimirse**.

~~~haproxy
frontend frontend_web
    bind *:8080
    bind *:8443 ssl crt /usr/local/etc/haproxy/certs/haproxy.pem
    http-request redirect scheme https code 301 unless { ssl_fc }
    default_backend backend_wordpress

backend backend_wordpress
    balance roundrobin
    http-response set-header X-NodoSur-Backend %[srv_name]
    option httpchk
    http-check send meth HEAD uri / ver HTTP/1.1 hdr Host nodosur07.tas hdr X-Forwarded-Proto https
    http-check expect status 200
    server web1 10.33.199.58:18081 check inter 3s fall 3 rise 2
    server web2 10.33.199.62:18080 check inter 3s fall 3 rise 2
~~~

**Comprobación en VM308:**

~~~bash
sudo docker exec nodosur-haproxy haproxy -c \
  -f /usr/local/etc/haproxy/haproxy.cfg
sudo docker exec nodosur-haproxy sed -n '1,100p' \
  /usr/local/etc/haproxy/haproxy.cfg
~~~

El valor HEAD / con status 200 sirve para retirar/reintegrar backends; **no prueba todas las operaciones de WooCommerce**. TLS termina en el proxy con certificado **autofirmado**; el tramo proxy→WordPress usa HTTP interno.

---

## 7. Pregunta «¿dónde está el código de WordPress o de MariaDB?»

**Web1 host:** /srv/nodosur/web1/html. **Web2 host:** /srv/nodosur/web2/html. **Dentro de ambos contenedores:** /var/www/html. Core principal en wp-admin/wp-includes, plugins en wp-content/plugins y temas en wp-content/themes. **Solo wp-content/uploads** está en NFS; no compartir el archivo wp-config.php, pues contiene material sensible.

~~~bash
# VM263 (Web1):
sudo ls /srv/nodosur/web1/html | head
sudo docker exec nodosur-web1 ls /var/www/html/wp-content
sudo docker exec nodosur-web1 ls /var/www/html/wp-content/plugins | head

# VM310 (Web2):
sudo ls /srv/nodosur/web2/html | head
sudo docker exec nodosur-web2 ls /var/www/html/wp-content/themes | head

# VM279:
sudo docker inspect nodosur-db-staging \
  -f 'Estado={{.State.Status}} Salud={{.State.Health.Status}}'
sudo docker inspect nodosur-db-staging \
  -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}} -> {{.Destination}}{{end}}{{end}}'
~~~

**Importante:** los Compose web usan imagen wordpress:7.1.2-php8.3-apache; el núcleo WordPress **persistido y verificado** es 7.1.3. Para reconstruir exactamente ese contenido se necesitan los directorios HTML persistentes, no basta el nombre de imagen.

La DB lógica es nodo_sur_final. El nombre del contenedor/volumen productivo conserva staging por motivos históricos: nodosur-db-staging y **nodosur-db-staging_db_stage_data**. No borrarlo ni crear un volumen distinto inadvertidamente.

---

## 8. Pregunta systemd: «¿quién levanta los contenedores y dónde se ejecuta Compose?»

Las unidades productivas **nodosur-web1.service** (VM263) y **nodosur-db-prod.service** (VM279) tenían WorkingDirectory confirmado **/home/tas_revision/nodosur-tas-grupo7**. Esa cuenta E2 fue caducada, pero su directorio **se conserva** por las dependencias de systemd. No borrarlo.

~~~bash
sudo systemctl cat nodosur-web1.service
sudo systemctl show nodosur-web1.service \
  -p WorkingDirectory -p ExecStart -p ActiveState -p UnitFileState
~~~

El archivo versionado de Web1 está en configs/systemd/nodosur-web1.service y la DB en configs/systemd/nodosur-db-prod.service. Las unidades de Web2 y HAProxy aparecen en Git, pero el nombre/ruta exactos cargados se confirma con systemctl list-unit-files y systemctl cat en sus hosts.

**Ojo:** systemctl active no basta para probar WordPress healthy, porque una unidad oneshot puede quedar activa mientras el contenedor falló. Comprobar también docker inspect, health checks cuando corresponda y HTTP.

---

## 9. Límites y prohibiciones durante la evaluación

**Lecturas seguras:** findmnt, exportfs -v, iptables -S, systemctl cat, docker inspect -f con campos concretos, docker exec ls/apache2ctl -t, named-checkconf, haproxy -c, curl, dig y abrir YAML/archivos de configuración no secretos.

**No improvisar:** editar exports/fstab/BIND/firewall/Compose, reiniciar NFS/DNS/DB/proxy, detener backends, crear carritos o pedidos, borrar el volumen DB, docker compose down -v, docker volume prune, git reset --hard, git clean o borrar /home/tas_revision.

**No imprimir secretos:** wp-config.php, contraseñas bajo /etc/nodosur/secrets, ni el PEM TLS que incorpora clave privada.

**Punto final:** si el profesor solicita un archivo de configuración específico y aún no consta su ruta instalada, primero consultar la VM y demostrar la evidencia; no inventar ni confundir el archivo de Git con el utilizado por el proceso.

**Fuentes de esta guía:** [arquitectura](../ARQUITECTURA.md), [inventario](../INVENTARIO.md), [matriz de flujos](MATRIZ-FLUJOS-E3.md), [NFS y hashes](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt), [verificación de cuatro VMs](../evidencias/e3/validacion-cuatro-vms-config-runtime-20261021.txt), [auditoría DNS y firewall](../evidencias/e3/auditoria-firewall-db-dns-20261021.txt), [hardening Apache](../evidencias/e3/apache-uploads-web1-web2-final-20261021.txt).
