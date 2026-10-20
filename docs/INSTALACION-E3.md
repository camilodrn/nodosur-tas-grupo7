# Instalación y adopción E3

**Procedimiento para un operador en laboratorio; no ejecutado por esta auditoría.** No aplicar todos los archivos de systemd en todas las VMs. Antes de intervenir: guardar configuración actual en un directorio privado fuera de Git, verificar un respaldo recuperable y acordar una ventana. Las cinco VMs existentes no son instalaciones vacías.

## 1. Requisitos y comprobaciones previas

Ubuntu con systemd; Docker Engine con Compose que soporte `config --quiet`, `up --wait` y `bind.create_host_path`; firewall Docker basado en iptables, conntrack y `iptables-restore`; Bash, coreutils, gzip, util-linux (`flock`, `findmnt`, `mountpoint`). BIND9 y NFS server en VM268, cliente NFS en VM263/310. Obtener Docker desde su distribución oficial compatible con la VM; no instalar mediante `curl | sh`.

Registrar sin credenciales:

```bash
hostnamectl
ip -br address
ip route
docker version --format '{{.Client.Version}} / {{.Server.Version}}'
docker compose version
sudo iptables -S FORWARD
sudo iptables -S DOCKER-USER
sudo ufw status verbose
```

Comprobar nombres/rutas de binarios: las unidades usan `/usr/bin/docker`; si la instalación legítima usa otra ruta, ajustar todas las unidades antes de validarlas. No sustituir el daemon ni el backend de firewall durante el cierre. El backend nftables nativo de Docker no tiene cadena DOCKER-USER; requiere un diseño distinto y esta configuración debe fallar sin publicar los servicios.

Capturar digest e IDs instalados antes de fijar las imágenes; no se verificaron los tags remotamente. Comprobar además versión del código WordPress montado. Fijar un digest **real capturado** después de probarlo, sin inventar uno ni actualizar versiones a ciegas.

```bash
docker image inspect wordpress:7.1.2-php8.3-apache --format '{{json .RepoDigests}}'
docker image inspect mariadb:10.11 --format '{{json .RepoDigests}}'
docker image inspect haproxy:3.2.23-alpine --format '{{json .RepoDigests}}'
```

## 2. Instalar archivos controlados por root

Desde la revisión auditada del repositorio, en cada host Docker pertinente:

```bash
sudo install -d -o root -g root -m 0755 /opt/nodosur/compose/{web1,web2,db-stage,proxy}
sudo install -d -o root -g root -m 0755 /opt/nodosur/configs/apache /usr/local/lib/nodosur
for role in web1 web2 db-stage proxy; do
  sudo install -o root -g root -m 0644 compose/"$role"/* /opt/nodosur/compose/"$role"/
done
sudo install -o root -g root -m 0644 configs/apache/nodosur-uploads.conf /opt/nodosur/configs/apache/
sudo install -o root -g root -m 0644 configs/firewall/nodosur-firewall-common.sh /usr/local/lib/nodosur/
sudo install -o root -g root -m 0755 configs/firewall/*-firewall.sh /usr/local/sbin/
sudo install -o root -g root -m 0755 scripts/e3/nodosur-check-web-storage.sh /usr/local/sbin/nodosur-check-web-storage
sudo install -o root -g root -m 0755 scripts/e3/nodosur-db-check-e3.sh /usr/local/sbin/nodosur-db-check-e3
```

La biblioteca de firewall es obligatoria: copiar solo los wrappers hará fallar la unidad antes de iniciar Compose. Confirmar con `namei -l /opt/nodosur/compose/web1/compose.yaml` y con las rutas `/usr/local/lib/nodosur` y `/usr/local/sbin`: ningún padre ni archivo ejecutado como root debe ser escribible por cuentas operativas. No dar permisos sobre el socket Docker.

## 3. NFS y WordPress

En VM268, inspeccionar `sudo exportfs -v`, `findmnt` y respaldos de uploads antes de elegir la ruta exportada. `configs/nfs/exports.example` y `fstab.example` son **propuestas**, no copias de los archivos reales. Integrar en `/etc/exports.d/nodosur.exports` y `/etc/fstab` solo después de confirmar origen, protocolo y datos. NFSv4.2 propuesto usa TCP 2049 limitado a `.58` y `.62`; si se conserva NFSv3 hay puertos RPC adicionales que deben inventariarse y restringirse.

Alinear UID/GID de `www-data` en ambos contenedores y propiedad de uploads en el servidor. Habitualmente es `33:33`, pero comprobarlo; no asumirlo ni usar `777`. Usar `root_squash`, `sync` y clientes explícitos. Conservar `hard`, `_netdev`, `nosuid`, `nodev`; `noexec` no impide que PHP interprete un archivo, de ahí la regla Apache de denegación.

Los montajes clientes deben existir en `/srv/nodosur/nfs/uploads` y ser NFS RW desde `10.33.199.59`. La unidad no inicia con un simple directorio local. Comprobar también que los datos visibles sean los correctos, no solo el origen del servidor.

Preparar `/srv/nodosur/web1/html` en VM263 y `/srv/nodosur/web2/html` en VM310 desde la instalación/backup aprobado. Mantener el mismo core, plugins, temas, `.htaccess` y prefijo de tablas; preservar el `wp-config.php` completo y los ocho salts compartidos. No dejar que cada instancia genere salts distintos. No ejecutar el instalador WordPress contra una DB existente.

- web1 sigue dependiendo de un `wp-config.php` local completo: el repositorio no contiene sus credenciales.
- web2 declara `WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db_password`, respaldado por `/etc/nodosur/secrets/cms_web62.password`.
- Un `wp-config.php` ya existente debe leer ese archivo o sus credenciales vigentes; la variable no modifica el archivo automáticamente. [Fragmento E3](../configs/wordpress/wp-config-e3.example.php) para integrar, sin duplicar constantes existentes.
- Configurar Host/URL HTTPS y confianza de `X-Forwarded-Proto` únicamente para el proxy efectivo. Verificar `REMOTE_ADDR` en el contenedor sin publicar cookies ni cabeceras sensibles.
- `wp-config.php` debe ser legible por PHP, sin escritura desde el servicio web (por ejemplo root con grupo numérico de PHP, 0640). Los archivos secretos montados por Compose conservan permisos del host: comprobar lectura por el UID real; no asumir que `uid/gid/mode` de un secret de archivo local se aplicará.

La nueva configuración `nodosur-uploads.conf` bloquea PHP/CGI y `.htaccess` dentro de uploads; validar `apache2ctl configtest` en la imagen antes de adoptar.

## 4. MariaDB y separación de entornos

Producción conserva proyecto/contenedor **`nodosur-db-staging`**, puerto **3306** y el volumen externo **`nodosur-db-staging_db_stage_data`**. Ese nombre se deriva del Compose original; confirmar en VM279 antes de adoptar:

```bash
docker inspect nodosur-db-staging --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}'
docker volume inspect nodosur-db-staging_db_stage_data --format '{{.Name}} {{.Mountpoint}}'
```

Si no coincide, **detener el procedimiento** y ajustar `volumes.db_stage_data.name` al volumen existente validado. No crear un volumen vacío para hacer desaparecer el error. Para una recuperación nueva, usar primero un volumen aislado según [recuperación](RECUPERACION-E3.md).

El secreto productivo mantiene `/etc/nodosur/secrets/db-stage-root.password`. Prepararlo desde custodia segura, como archivo de una línea, no vacío, con directorio 0700 y archivo 0600 root. No cambiarlo esperando que MariaDB actualice una contraseña ya almacenada: las variables de inicialización no reconfiguran un volumen existente. Confirmar grants específicos `cms_web58` y `cms_web62`, restringidos a cada backend y a la base `nodo_sur_final`; no conceder acceso root remoto. Un dump de esa base no incluye automáticamente todos los usuarios/grants de `mysql`.

Staging nuevo es `nodosur-db-lab`, 13307, volumen `db_lab_data`, secreto `db-lab-root.password`. Es una instalación vacía independiente hasta cargar una copia autorizada. Su backup referencia ese contenedor. No habilitar staging por defecto en producción ni usar nombres anteriores de staging como supuesto entorno de pruebas.

## 5. HAProxy y DNS

Instalar el PEM productivo bajo `/etc/nodosur/tls/haproxy-www.pem`, fuera de Git, con permisos mínimos que permitan al usuario efectivo de HAProxy leerlo. Contiene certificado y clave privada; no imprimirlo. Validar SAN, vigencia, correspondencia clave/certificado y hora del sistema. Distribuir solo el certificado público por canal confiable.

En una ventana controlada puede validarse la configuración con un contenedor efímero, sin publicar puertos:

```bash
cd /opt/nodosur
docker compose -f compose/proxy/compose.prod.yaml config --quiet
docker compose -f compose/proxy/compose.prod.yaml run --rm --no-deps haproxy \
  haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

El proxy de laboratorio usa otro proyecto/contenedor y loopback; el certificado es `/etc/nodosur/tls/haproxy.pem`. No es el servicio productivo.

En BIND integrar `named.conf.local.example`, revisar ACL de `named.conf.options.example` y la zona. Apex/www deben apuntar a `.194`; no reemplazar zonas ajenas ni eliminar registros heredados sin verificar sus consumidores. El serial `2026102001` es una referencia: usar uno **mayor que el serial actualmente servido**, validar `named-checkconf` y `named-checkzone`, y solo entonces recargar la zona. La recursión y transferencias no autorizadas quedan deshabilitadas en la propuesta.

## 6. Unidades por VM y secuencia

Instalar con root:root 0644 únicamente las unidades de cada rol en `/etc/systemd/system`:

| VM | Unidades |
|---|---|
| 263 | `nodosur-docker-firewall-web1.service`, `nodosur-web1.service` |
| 310 | `nodosur-docker-firewall-web2.service`, `nodosur-web2.service` |
| 279 | `nodosur-db-prod-firewall.service`, `nodosur-db-prod.service`, `nodosur-db-backup.service`, `nodosur-db-backup.timer` |
| 308 | `nodosur-proxy-firewall.service`, `nodosur-proxy.service` |
| 268 | BIND/NFS existentes; no hay unidad real de réplica/mantenimiento versionada |

Los archivos `nodosur-web1-firewall.conf` y `web2` son drop-ins de compatibilidad; la dependencia ya está en la unidad principal. Si existen drop-ins antiguos, reconciliarlos con `systemctl cat` y sustituir la referencia a `nodosur-docker-firewall.service`. No instalar una unidad genérica inexistente.

En VM279 instalar también:

```bash
sudo install -o root -g root -m 0755 scripts/e3/nodosur-backup-db.sh /usr/local/lib/nodosur/
sudo install -o root -g root -m 0755 scripts/e3/nodosur-backup-db-prod.sh /usr/local/sbin/nodosur-backup-db-prod
sudo install -o root -g root -m 0755 scripts/e3/nodosur-backup-db-staging.sh /usr/local/sbin/nodosur-backup-db-staging
```

`nodosur-db-backup.service.d/docker.conf` es compatibilidad con el servicio antiguo; la unidad base completa ya usa el wrapper productivo. Antes de habilitar el timer, revisar timers/crontabs existentes para no duplicar tareas. El horario nuevo 03:00 UTC con hasta cinco minutos de dispersión es una propuesta. `Persistent=true` puede lanzar una ejecución pendiente al habilitarlo; usa `Requisite` y no arranca la DB por sí solo.

Tras instalar y revisar: ejecutar `systemd-analyze verify` sobre unidades pertinentes, `systemctl daemon-reload`, comprobar `systemctl cat` y habilitar los servicios del rol. Arrancar en orden **NFS/DNS → DB con firewall → web con firewall → proxy con firewall → timer**. No activar MariaDB nativa y Docker en el mismo puerto. Validar un backend por vez antes de intervenir el otro. Los comandos de inicio/reinicio quedan a cargo del operador; no se ejecutaron durante esta auditoría.
