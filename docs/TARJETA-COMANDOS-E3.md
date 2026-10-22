# Tarjeta rápida · Comandos seguros de Entrega 3
**Para la revisión individual en el puesto · No ejecutar comandos destructivos.**
[Guía explicada y 40 preguntas](GUIA-ESTUDIO-INDIVIDUAL-E3.md) · **[Mapa de archivos y reglas](MAPA-CONFIGURACIONES-E3.md)** · [Arquitectura](../ARQUITECTURA.md) · [Inventario](../INVENTARIO.md)

**¿No entiendes un parámetro como -f, -I, -k, --resolve, -M, -p o una tubería?** Consulta primero [Comandos explicados paso a paso](COMANDOS-EXPLICADOS-E3.md). Las órdenes de esta tarjeta son una referencia rápida, no sustituyen entender qué hacen.

## Antes de tocar la terminal

**Primero:** hostname, whoami, pwd, VPN, cuenta autorizada y rol de la VM. No leer credenciales ni wp-config.php ni PEM privado. **Segundo:** confirmar que el comando es de consulta. **Tercero:** explicar qué salida demuestra y qué no demuestra.

| VM | SSH E3 desde Fedora | Rol |
|---|---|---|
| 268 | ssh tas_revision_e3@10.33.195.205 | DNS/NFS |
| 263 | ssh tas_revision_e3@10.33.195.202 | Web1 |
| 310 | ssh tas_revision_e3@10.33.195.208 | Web2 |
| 279 | ssh tas_revision_e3@10.33.195.226 | MariaDB |
| 308 | ssh tas_revision_e3@10.33.195.194 | HAProxy |

Las contraseñas se entregan por **canal privado**; ninguna está en esta guía.

## Fedora (VPN conectada)

~~~bash
dig @10.33.195.205 nodosur07.tas A +short
dig @10.33.195.205 nodosur07.tas SOA +noall +answer

curl --noproxy '*' -sSI --resolve nodosur07.tas:80:10.33.195.194 \
  http://nodosur07.tas/ | grep -Ei '^(HTTP/|location:)'

curl --noproxy '*' -ksSI --resolve nodosur07.tas:443:10.33.195.194 \
  https://nodosur07.tas/ | grep -Ei '^(HTTP/|x-nodosur-backend:)'
~~~

-k sirve solo para diagnosticar certificado **autofirmado**, NO para demostrar confianza TLS.

## VM268 — DNS/NFS

**¿Dónde está el código de las reglas?** La zona y la restricción AXFR comprobadas están en /etc/bind/named.conf.local y los registros en /etc/bind/db.nodosur07.tas. Para NFS, el export de datos /srv/nodosur/uploads está comprobado, pero falta confirmar el archivo exacto de exportación: consultar exportfs -v y /etc/exports o /etc/exports.d, como explica el [mapa](MAPA-CONFIGURACIONES-E3.md).

~~~bash
hostname
sudo systemctl is-active bind9
sudo named-checkconf -z
sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
sudo grep -n -A 8 -B 2 'zone "nodosur07.tas"' /etc/bind/named.conf.local

sudo exportfs -v
sudo ls -ld /srv/nodosur/uploads
sudo ls /srv/nodosur/uploads | head
~~~

**NFS servidor:** /srv/nodosur/uploads. **DNS zona:** /etc/bind/db.nodosur07.tas. **BIND:** /etc/bind/named.conf.local. **NO** editar ni reiniciar para demostrar.

## VM263 — Web1

**¿Dónde está la regla?** Apache: /etc/nodosur/apache/nodosur-uploads.conf (también en configs/apache/ del repo). Firewall: reglas iptables DOCKER-USER, servicio nodosur-docker-firewall.service; usar systemctl cat para encontrar su script ejecutado.

~~~bash
hostname
sudo docker inspect -f 'Estado={{.State.Status}}' nodosur-web1
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET
sudo ls -ld /srv/nodosur/web1/html
sudo docker exec nodosur-web1 ls /var/www/html/wp-content
sudo docker exec nodosur-web1 ls /var/www/html/wp-content/plugins | head
sudo docker exec nodosur-web1 apache2ctl -t
sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf
sudo iptables -S DOCKER-USER
sudo systemctl show nodosur-web1.service -p WorkingDirectory -p ActiveState

sudo docker inspect nodosur-web1 -f \
  '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'
~~~

**HTML host:** /srv/nodosur/web1/html. **NFS host:** /srv/nodosur/nfs/uploads. **uploads contenedor:** /var/www/html/wp-content/uploads.

## VM310 — Web2

**¿Dónde está la regla?** Mismos roles y rutas de Apache/firewall que Web1; código WP local de Web2 en /srv/nodosur/web2/html. El NFS está montado en /srv/nodosur/nfs/uploads.

~~~bash
hostname
sudo docker inspect -f 'Estado={{.State.Status}}' nodosur-web2
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET
sudo ls -ld /srv/nodosur/web2/html
sudo docker exec nodosur-web2 ls /var/www/html/wp-content/themes | head
sudo docker exec nodosur-web2 apache2ctl -t
sudo iptables -S DOCKER-USER

sudo docker inspect nodosur-web2 -f \
  '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'
~~~

**HTML host:** /srv/nodosur/web2/html. **NFS:** igual montaje que Web1. No confundir **contenedor** con **VM**.

## VM279 — MariaDB

~~~bash
sudo docker inspect nodosur-db-staging \
  -f 'Estado={{.State.Status}} Salud={{.State.Health.Status}}'

sudo docker inspect nodosur-db-staging \
  -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}Volumen={{.Name}} -> {{.Destination}}{{end}}{{end}}'

sudo docker volume ls --filter name=nodosur-db-staging_db_stage_data
sudo systemctl show nodosur-db-prod.service -p ActiveState -p WorkingDirectory
sudo iptables -S DOCKER-USER
~~~

**Base lógica:** nodo_sur_final. **Contenedor histórico:** nodosur-db-staging. **Volumen real:** nodosur-db-staging_db_stage_data. **Nunca borrarlo.**

## VM308 — HAProxy

**Archivo de código del balanceo:** compose/proxy/haproxy.prod.cfg en Git; /usr/local/etc/haproxy/haproxy.cfg dentro del contenedor. No imprimir el archivo privado PEM.

~~~bash
sudo docker inspect nodosur-haproxy -f 'Estado={{.State.Status}}'

sudo docker exec nodosur-haproxy haproxy -c \
  -f /usr/local/etc/haproxy/haproxy.cfg

for destino in 10.33.199.58:18081 10.33.199.62:18080; do
  curl --noproxy '*' --connect-timeout 5 --max-time 15 -sS \
    -o /dev/null -w '%{http_code}\n' \
    -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' \
    "http://$destino/"
done

sudo docker logs --since 30m nodosur-haproxy 2>&1 |
  grep -Ei 'Server backend_wordpress/web[12] is (DOWN|UP)' | tail -n 15
~~~

**Repo:** compose/proxy/haproxy.prod.cfg; **contenedor:** /usr/local/etc/haproxy/haproxy.cfg. **Privado NO leer:** /etc/nodosur/tls/haproxy-www.pem.

## Lo que responder si pregunta NFS

«VM268 exporta **/srv/nodosur/uploads**. Web1 y Web2 montan ese directorio en sus hosts en **/srv/nodosur/nfs/uploads**; Docker lo presenta a WordPress como **/var/www/html/wp-content/uploads**. Se comparten las imágenes, no todo el código de WordPress. Muestro findmnt y docker inspect, y comparo SHA-256 si hace falta».

## Qué NO ejecutar en una demostración

- docker compose down -v; docker volume prune.
- git reset --hard, git clean, git pull indiscriminado en VMs.
- userdel -r de tas_revision; todavía existen directorios usados por systemd.
- systemctl restart/mask de DNS/NFS/DB/proxy sin autorización.
- docker stop de Web2 salvo fallo controlado expresamente autorizado.
- cat de wp-config.php, archivo PEM TLS, passwords o archivos privados.
- Pruebas SQL destructivas, pedidos reales ni reconstrucción de la DB.

**Clave:** poder explicar **qué hace cada comando** y por qué su resultado no garantiza más de lo que observamos.
