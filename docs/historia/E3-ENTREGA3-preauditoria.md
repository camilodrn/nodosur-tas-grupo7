# Entrega 3 — Nodo Sur

## Objetivo

Implementar y validar una arquitectura distribuida para
WordPress y WooCommerce, utilizando contenedores Docker,
balanceo de carga, almacenamiento compartido, base de
datos separada y mecanismos de recuperación.

## Arquitectura implementada

| Rol | VM | IP administrativa | IP interna |
|---|---|---|---|
| DNS, NFS y respaldos | 268 | 10.33.195.205 | 10.33.199.59 |
| WordPress 1 | 263 | 10.33.195.202 | 10.33.199.58 |
| WordPress 2 | 310 | 10.33.195.208 | 10.33.199.62 |
| MariaDB Docker | 279 | 10.33.195.226 | 10.33.199.60 |
| HAProxy | 308 | 10.33.195.194 | 10.33.199.61 |

## Funcionamiento

BIND9 administra la zona nodosur07.tas y resuelve
el dominio principal y www a 10.33.195.194.

HAProxy recibe HTTP y HTTPS, redirige HTTP a HTTPS
y distribuye las solicitudes mediante roundrobin:

- web1: 10.33.199.58:18081
- web2: 10.33.199.62:18080

Los health checks HTTP retiran temporalmente un
backend cuando deja de responder y lo reincorporan
cuando vuelve a estar disponible.

Ambos WordPress utilizan MariaDB Docker en
10.33.199.60:3306 y almacenamiento NFS compartido
para los archivos subidos.

El tráfico HTTPS utiliza un certificado autofirmado
con SAN para nodosur07.tas y www.nodosur07.tas.

## Validaciones realizadas

### Balanceo

Se realizaron diez solicitudes HTTPS consecutivas:

- 10 respuestas HTTP 200.
- 5 respuestas desde web1.
- 5 respuestas desde web2.

### Falla y recuperación

Se detuvo de forma controlada web2.

HAProxy detectó el backend como DOWN.
Durante la falla, ocho solicitudes consecutivas
respondieron HTTP 200 desde web1.

Al iniciar nuevamente web2, HAProxy detectó
su recuperación mediante un health check HTTP 200.

Se realizaron otras diez solicitudes exitosas,
distribuidas cinco por cada backend.

### Coherencia del carrito

Se creó un carrito WooCommerce en web1, se agregó
el producto de prueba ID 43 y se verificó su presencia
desde web2.

El producto fue retirado correctamente y la prueba
finalizó con código de salida 0.

Evidencia:
evidencias/e3/carrito-coherencia-postmigracion.txt

### Seguridad de red

Se verificó que:

- Los backends autorizados acceden a MariaDB.
- El proxy no puede conectarse directamente a MariaDB.
- La VM de MariaDB no puede conectarse al HTTPS del proxy
  por la interfaz administrativa.
- Las reglas DOCKER-USER muestran paquetes descartados.
- El acceso HTTPS desde la VPN institucional funciona.

### Respaldos

La VM de MariaDB genera respaldos comprimidos y
sus archivos SHA-256.

Se verificó la réplica externa del respaldo
nodo_sur_final-20261020-190237.sql.gz.

Resultados:
- Copia disponible en VM268, directorio archive.
- SHA-256 correcto.
- Compresión GZIP válida.
- 52 tablas identificadas en el respaldo.

El servicio nodosur-remote-backup-maintenance realiza
validaciones periódicas de los respaldos recibidos.

## Servicios persistentes

Los servicios productivos utilizan systemd para
gestionar los contenedores y las tareas de respaldo.

La configuración versionada se encuentra en:

- compose/proxy/compose.prod.yaml
- compose/proxy/haproxy.prod.cfg
- compose/db-stage/compose.prod.yaml
- configs/systemd/
- configs/firewall/
- scripts/e3/

Los certificados, las credenciales y los secretos
se mantienen fuera del repositorio.

## Limitaciones

La implementación tolera la caída de un backend web,
pero no ofrece alta disponibilidad de todos los servicios.

Persisten puntos únicos de fallo:

- HAProxy.
- MariaDB.
- DNS autoritativo.
- Servidor NFS y repositorio de respaldos.

El certificado TLS es autofirmado y requiere confianza
explícita del cliente.

La reproducción completa depende de las redes,
volúmenes, certificados y secretos configurados en
las VMs de laboratorio. El repositorio no constituye
un aprovisionamiento automático completo.

## Conclusión

La arquitectura de cinco VMs permite distribuir
las solicitudes, conservar el estado compartido
de WooCommerce y mantener la atención del sitio
ante la caída de uno de los servidores web.

Las pruebas se realizaron sobre los servicios
productivos de la Entrega 3.
