# Entrega 3 — Publicación resiliente, contenedores y seguridad

**Grupo 7 · Taller de Administración de Sistemas · Octubre de 2026.**

Esta página ordena lo que podemos **mostrar y defender técnicamente** de Nodo Sur. La pauta escrita del proyecto incluye un informe de avance; según la indicación posterior comunicada por el equipo, la evaluación de esta entrega se enfocará en la **demostración y defensa técnica**, sin un informe separado. Mantener la documentación de GitHub como respaldo, no como sustituto de la demostración.

## Objetivo técnico

Escalar WordPress/WooCommerce de la instalación tradicional a dos backends en Docker, con HAProxy como entrada HTTPS, MariaDB única, uploads NFS compartidos y controles de red. La condición principal de E3 es **mantener la atención del sitio cuando uno de los dos backends web deja de funcionar**; no se exige afirmar redundancia de toda la infraestructura.

[Arquitectura](../ARQUITECTURA.md) · [Inventario](../INVENTARIO.md) · [Matriz de accesos](MATRIZ-FLUJOS-E3.md) · [Rúbrica](RUBRICA-E3.md) · [Reconstrucción por host](DESPLIEGUE-REPRODUCIBLE-E3.md) · [Demo de 12–15 minutos](PLAN-DEMOSTRACION-E3.md)

## Resultado de las pruebas disponibles

| Comportamiento a defender | Evidencia que tenemos | Interpretación correcta |
|---|---|---|
| HAProxy distribuye peticiones | [8 respuestas en alternancia, 4/4](../evidencias/e3/balanceo-roundrobin.txt) | Roundrobin observado con ambos web disponibles |
| Un backend deja de atender | [Detención controlada, log `DOWN` y 8/8 HTTP 200 vía web1](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt) | Continuidad demostrada después de la detección de caída; no prueba ausencia de errores en el intervalo de detección |
| Web2 vuelve | [Actualización WordPress 7.1.3, log `UP` de HAProxy, 8/8 HTTP 200 repartidos 4/4](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt) | Reincorporación automática por health check Layer7 HTTP 200 verificada; no hay RTO formal medido |
| Configuración y publicación HTTPS | [`haproxy -c` correcto y redirección HTTP 301](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt), [6 HTTPS exitosos 3/3](../evidencias/e3/https-haproxy.txt) | Proxy operativo; sin demostrar confianza pública del certificado |
| Certificado TLS | [SAN, fechas y huella pública](../evidencias/e3/certificado-publico-y-repo-local-20261021.txt) | Autofirmado, válido por fechas y nombres, **no** reconocido automáticamente por navegadores |
| Contenido compartido por NFS | [Mismo archivo, tres SHA-256 idénticos](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) | Ambos web entregan bytes idénticos al origen; no prueba escritura cruzada de archivos nuevos |
| Coherencia de aplicación | [Carrito del producto 43 compartido](../evidencias/e3/carrito-coherencia-postmigracion.txt) | Un flujo de carrito entre web1 y web2; no todas las sesiones ni operaciones concurrentes |
| Reglas de red | [`DOCKER-USER` web1/web2](../evidencias/e3/firewall-docker-user-web1-web2-20261021.txt), [conectividad observada](../evidencias/e3/acceso-proxy-backends-20261020.txt) | Restricción de orígenes a puertos web; las pruebas negativas TCP no localizan por sí solas toda la causa |
| Despliegue por host | [Compose web1/web2 y mounts](../evidencias/e3/compose-productivo-web1-web2-y-php-20261021.txt), [DB/proxy](../evidencias/e3/compose-productivo-db-proxy-20261021.txt) | Definiciones Compose correctas en cuatro hosts; contenedores running |
| Pruebas de los cambios auditados | [25 pruebas locales OK y barrido heurístico](../evidencias/e3/validacion-local-fedora-20261021.txt) | Resultado de la rama local de Codex con dobles de Docker/iptables; **no acredita adopción en producción** |

## Funcionamiento de la plataforma

1. BIND resuelve `nodosur07.tas` hacia el proxy `10.33.195.194`.
2. HAProxy atiende HTTP 80/HTTPS 443, redirige HTTP, termina TLS y consulta la salud de web1/web2 con `HEAD /`, respuesta esperada 200.
3. Los backends están en `10.33.199.58:18081` (VM263) y `10.33.199.62:18080` (VM310).
4. Los dos WordPress consultan MariaDB `10.33.199.60:3306` (VM279), con volumen de datos persistente histórico `nodosur-db-staging_db_stage_data`.
5. El directorio `wp-content/uploads` está montado en ambos web desde NFS de VM268 (`10.33.199.59`).
6. Las reglas `DOCKER-USER` de ambos web limitan sus puertos internos a conexiones desde el proxy `10.33.199.61`. Los secretos no deben versionarse.

## Endurecimiento de uploads instalado (21/10/2026)

Se incorporó la configuración [`configs/apache/nodosur-uploads.conf`](../configs/apache/nodosur-uploads.conf) para denegar PHP/PHTML/PHAR y ejecución CGI dentro de `wp-content/uploads`. Antes de su instalación se verificó `apache2ctl -t` y comportamiento HTTP de un contenedor Apache efímero aislado: archivo de texto `200` y archivo PHP existente `403`, ambos inocuos.

La configuración quedó montada **en web2 (VM310) y después en web1 (VM263)**, desde `/etc/nodosur/apache/nodosur-uploads.conf` con bind de solo lectura y sin creación automática de ruta. Ambos WordPress siguieron `running`. La verificación final desde VM308 mostró:

- **Web1**: portada `200`, `/tienda/` `200`, imagen real de uploads en NFS `200`, URL PHP inexistente bajo uploads `403`.
- **Web2**: las mismas respuestas `200 / 200 / 200 / 403`.
- **HAProxy**: seis respuestas HTTPS `200` repartidas **3 web1 / 3 web2**.

Evidencia: [resultado final de los dos backends](../evidencias/e3/apache-uploads-web1-web2-final-20261021.txt). El `403` de producción se observó consultando una ruta inexistente: se presenta como comprobación de la regla HTTP, no como ensayo de ejecución de un PHP subido. Los respaldos previos de Compose permanecen fuera de Git en los hosts web.

**Nota operativa:** se comprobaron [huellas semánticas idénticas de Compose entre Fedora y VM263/VM310](../evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt). La [auditoría Git posterior](../evidencias/e3/git-backends-cambios-locales-20261021.txt) muestra que VM263 sigue en `e3/backend1` (`8b067ef`) y VM310 en `e3/backend2` (`667d7d9`); en cada una el único cambio local reportado es la adición del bind de hardening Apache en su Compose, y `git diff --check` no reportó problemas. **Se conservarán esas ediciones locales sin `pull`/`reset`, commits productivos ni recreación de contenedores por motivos puramente Git.** La rama de cierre representa el trabajo versionado, no una revisión instalada idéntica en cada VM. El PR #2 sigue sin fusionar con `e3/integracion`.

## Alineación de WordPress y recuperación posterior (21/10/2026)

Tras respaldar archivos privados de web2 y generar/verificar un respaldo reciente de MariaDB, el operador preparó el paquete oficial WordPress 7.1.3 y actualizó **solo el core de web2** con el contenedor detenido. Se conservaron `wp-config.php`, `wp-content` y NFS; pasaron siete pruebas PHP lint aisladas. Web2 volvió a `running`, Apache reportó `Syntax OK` (aviso no fatal ServerName), core declaró **7.1.3** y esquema 61833. Desde VM308, portada, tienda e imagen NFS devolvieron 200, PHP bajo uploads 403. HAProxy registró `web2 is UP` por `Layer7 check passed, code: 200` y 8 solicitudes al frontend obtuvieron HTTP 200, repartidas **4/4**.

La secuencia completa incluye [evento DOWN y continuidad atendida por web1](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt) y [evento UP y regreso del balanceo](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt), respaldada por el [plan de alineación](PLAN-ALINEACION-WORDPRESS-E3.md). No se cuantificaron errores durante el intervalo previo al DOWN ni se ensayó restauración funcional integrada. Se auditaron las cuatro huellas de directorios postactualización: los 9817 archivos de `wp-admin`, `wp-includes`, plugins y temas presentan cantidades y hashes idénticos en web1/web2 ([evidencia](../evidencias/e3/comparacion-post-upgrade-web1-web2-20261021.txt)). Los archivos principales seleccionados de la raíz de WordPress también tienen [SHA-256 idéntico](../evidencias/e3/wordpress-raiz-sha256-igual-web1-web2-20261021.txt), excluyendo `wp-config.php`; continúa pendiente evaluar configuración efectiva y estado dinámico.

## Comprobación adicional de MariaDB y HAProxy (21/10/2026)

Desde sus VMs, el operador comprobó `git status --short` sin cambios locales y `docker compose config --quiet` correcto en ambos roles. MariaDB `running/healthy` con imagen `mariadb:10.11`, volumen histórico exacto y secreto root externo presente. HAProxy `running` con imagen `haproxy:3.2.23-alpine`, validación `haproxy -c` correcta y archivo TLS presente. [Evidencia](../evidencias/e3/preflight-db-proxy-compose-20261021.txt). Se verificó únicamente presencia/no vacío de archivos privados; no sus permisos o contenido. Un estado Git limpio no asegura igualdad de ramas o commits con el PR. En una [auditoría posterior](../evidencias/e3/permisos-publicacion-git-db-proxy-20261021.txt) se comprobaron además permisos DB 700/600 root, 3306 enlazado únicamente a 10.33.199.60, TLS de proxy 750/640 root:UNKNOWN, y puertos 80/443 enlazados a 10.33.195.194. Las ramas locales son e3/database (488cb27) y e3/proxy (fdaba39); son despliegues por rol, no el commit del PR. La [auditoría complementaria del certificado](../evidencias/e3/haproxy-certificado-gid99-20261021.txt) confirmó que el GID 99 sin nombre resuelto en el anfitrión corresponde al grupo `haproxy` dentro del contenedor (UID/GID 99). La lectura efectiva mediante `test -r` fue positiva y el montaje del PEM tiene `RW=false`. No fue necesario modificar permisos; esto no equivale a auditar exhaustivamente ACL ni otras identidades del host.

## Auditoría adicional de segmentación y DNS (21/10/2026)

La [evidencia de firewall MariaDB y DNS](../evidencias/e3/auditoria-firewall-db-dns-20261021.txt) muestra reglas `DOCKER-USER` efectivas para 3306: excepciones de origen `10.33.199.59` (VM268), `.62` (web2) y `.58` (web1), seguidas de `DROP` para otros orígenes sobre el puerto original; también hay reglas para el puerto `13307` cuya necesidad histórica no se ha aclarado, pero **no se observó escucha TCP ni publicación/NAT Docker** en la comprobación posterior. UFW permanece activo, con política `deny incoming` y permisos limitados de SSH/DB. Estas observaciones no prueban por sí solas aceptación final de cada flujo ni que la configuración cubra toda la red.

BIND9 contestó SOA autoritativo por UDP/TCP (`aa`, `NOERROR`). Inicialmente AXFR desde Fedora por VPN permitió transferir nueve registros (`XFR size: 9 records`). Se verificó BIND 9.18.39, zona primaria sin `allow-transfer` explícito y un solo NS publicado. Tras preparar y validar una copia con respaldo privado, **se aplicó `allow-transfer { none; };` únicamente a `nodosur07.tas`**, se validó con `named-checkconf -z` y se ejecutó `rndc reconfig` sin reinicio. **Verificación posterior desde Fedora: SOA UDP/TCP autoritativo `NOERROR`, `www` hacia `10.33.195.194` y AXFR `REFUSED`** ([evidencia](../evidencias/e3/auditoria-firewall-db-dns-20261021.txt)). El resultado no certifica pruebas desde todas las redes ni redundancia DNS; se preserva respaldo para reversión.

## Persistencia después de reinicio (ensayo Fedora, 21/10/2026)

[Registro de la prueba y verificación posterior](../evidencias/e3/persistencia-reinicio-ensayo-fedora-20261021.txt): tras reiniciar **solo** los contenedores del ensayo, MariaDB recuperó `healthy`, WordPress conservó instalación/administrador en ambos servidores, y un archivo ficticio mantuvo el mismo SHA-256 desde ambas webs; después fue eliminado. Las primeras seis peticiones HTTP 200 del proxy pasaron solo por Web2 (el validador original salió con error). **Sin nuevos reinicios**, los logs de HAProxy mostraron Web1 `DOWN` por conexión rechazada y posteriormente `UP` tras health check Layer7 HTTP 200. En la comprobación posterior ambos WordPress devolvieron HTTP 200 y **ocho solicitudes se distribuyeron 4/4**. FurgoPlus permaneció saludable. El script se ajustó para esperar ambos nodos en futuras ejecuciones; no se midió RTO y este ensayo no sustituye la prueba de las cinco VMs del iLab.

## WordPress inicializado en el ensayo (21/10/2026)

La [instalación ficticia con `wp_install()`](../evidencias/e3/wordpress-instalado-ensayo-fedora-20261021.txt) tuvo éxito (`WORDPRESS_LAB_INSTALL_OK`), y HAProxy respondió HTTP 200 en 6/6 solicitudes, repartidas 3/3 entre Web1 y Web2. La ausencia de `sendmail` no impidió terminar; el ensayo no incluye correo de producción. El estado persistente del WordPress ficticio quedó comprobado posteriormente en el reinicio controlado del propio laboratorio.

## Validación de uploads compartidos del ensayo (21/10/2026)

La [prueba de escritura/lectura cruzada](../evidencias/e3/volumen-compartido-ensayo-fedora-20261021.txt) pasó: misma identidad y montaje `shared_uploads`, Web1 creó archivo temporal como `www-data`, Web2 leyó SHA-256 igual y el archivo se eliminó. MariaDB de ensayo permaneció `healthy` y los seis contenedores FurgoPlus continuaron `healthy`. La prueba usa **volumen local Docker**, no NFS productivo.

## Ensayo local de arranque multicontenedor (21/10/2026)

Se levantó en Fedora el proyecto aislado `nodosur-e3-ensayo` a partir de `compose/e3-lab/compose.yaml`: MariaDB 10.11 healthy, WordPress web1/web2 y HAProxy 3.2.23 running; redes y volúmenes exclusivos, solo 127.0.0.1:19090 publicado, HTTP 302 y los seis contenedores FurgoPlus aún saludables ([evidencia](../evidencias/e3/primer-arranque-ensayo-fedora-20261021.txt)). Este era el resultado **inicial**; las pruebas posteriores sí demostraron ambos backends, SQL, instalación del CMS y volumen compartido local, **pero no NFS/TLS reales ni una reconstrucción productiva desde cero**.

## Verificación integral de lectura desde Fedora (21/10/2026)

[Último control funcional](../evidencias/e3/validacion-integral-fedora-20261021.txt): los registros A de DNS resolvieron correctamente por UDP y TCP (8/8), HTTP devolvió 301 a HTTPS, el proxy respondió 6/6 HTTP/2 200 repartidos 3/3 entre los dos backends y WooCommerce `/tienda/` devolvió HTTP 200. Estas consultas no generaron pedidos, no recrearon servicios ni validaron todas las funciones de la tienda.

## Qué no está demostrado todavía

- Sí hay registros `DOWN/UP` conservados en la nueva prueba controlada de falla y recuperación; no se ha medido formalmente un **RTO/RPO** ni la posible pérdida de solicitudes durante el umbral de detección.
- El montaje NFS y las lecturas idénticas no certifican por sí solos que todos los plugins, salts, sesiones o pedidos concurrentes sean coherentes. **El desfase de WordPress 7.1.3 frente a 7.1.2 fue corregido:** ahora ambos nodos declaran 7.1.3; la comparación de directorios por SHA-256 ya dio cuatro coincidencias (núcleo y plugins/temas), y también coinciden los archivos principales seleccionados de raíz, excluyendo `wp-config.php`; resta revisar diferencias de configuración. WooCommerce 11.1.0 y los árboles completos de plugins/temas coincidían según [evidencia previa](../evidencias/e3/wordpress-arboles-core-plugins-temas-20261021.txt). Se verificaron [respaldo privado HTML](../evidencias/e3/respaldo-html-web2-pre-upgrade-20261021.txt) y [SQL reciente](../evidencias/e3/respaldo-mariadb-pre-cambio-web2-20261021.txt); **no hay ensayo de restauración real**.
- Los cuatro Compose funcionan donde están instalados, pero un checkout nuevo no reconstruye automáticamente la VPN, las VMs, los secretos, el TLS, los datos y el almacenamiento.
- HAProxy, MariaDB, DNS y NFS son **SPOF**. No se ha demostrado continuidad ante caída de cualquiera de esas dependencias compartidas.
- La protección Apache de `uploads` **sí está instalada** en ambos WordPress, con evidencia aislada y productiva. Otras propuestas de Codex para firewall, systemd, HAProxy y backups **no se han aplicado a las VMs** y requieren validación separada.

## Antes de la defensa

La falla controlada con logs DOWN/UP ya fue ensayada y documentada. Para la defensa corresponde revalidar estado de servicios, balanceo y endpoints, y preparar la demostración sin repetir la falla si no hay una ventana autorizada. Explicar el uso de NFS, MariaDB compartida, Docker Compose, `DOCKER-USER`, el umbral de health checks y los puntos únicos de fallo.

## Nota sobre E4

El ensayo de restauración de MariaDB (52 tablas) y la extracción de WordPress (10.313 archivos coincidentes por SHA-256) se hicieron por separado en laboratorio aislado. Son avances valiosos para la continuidad operacional de **Entrega 4**, pero no equivalen a restauración funcional integrada de WordPress + MariaDB, ni sustituyen los criterios técnicos de E3.
