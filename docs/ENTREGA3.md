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
| Un backend deja de atender | [8 respuestas HTTP 200 de web1](../evidencias/e3/failover-web2-detenido.txt) | Continuidad observada durante la prueba con web2 fuera del balanceo; el archivo no contiene la orden de parada ni log `DOWN` |
| Web2 vuelve | [8 respuestas HTTP 200, 4/4](../evidencias/e3/recuperacion-web2.txt) | Ambos backends vuelven a recibir tráfico; sin log `UP` ni tiempo formal medido |
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

**Nota operativa:** se comprobaron [huellas semánticas idénticas de Compose entre Fedora y VM263/VM310](../evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt). Los checkouts instalados en VM263 y VM310 tienen ediciones locales de `compose/web1/compose.yaml` y `compose/web2/compose.yaml`. GitHub también contiene los cambios, pero **no se debe ejecutar `git pull`/`reset` indiscriminadamente en esas VMs** hasta reconciliar los checkouts sin reemplazar los datos ni las configuraciones activas. El PR #2 sigue sin fusionar con `e3/integracion`.

## Qué no está demostrado todavía

- No hay registros `DOWN/UP` conservados en las evidencias de failover ni un **RTO/RPO medido**.
- El montaje NFS y las lecturas idénticas no certifican por sí solos que todos los plugins, salts, sesiones o pedidos concurrentes sean coherentes. **Se detectó discrepancia del WordPress instalado**: web1 7.1.3 frente a web2 7.1.2, respaldada por hashes distintos de `wp-admin` y `wp-includes`; en cambio, los árboles completos de plugins y temas tienen hashes idénticos, al igual que WooCommerce 11.1.0 ([evidencia](../evidencias/e3/wordpress-arboles-core-plugins-temas-20261021.txt)). No alinear el core sin revisión de respaldo, compatibilidad y plan de actualización coordinada.
- Los cuatro Compose funcionan donde están instalados, pero un checkout nuevo no reconstruye automáticamente la VPN, las VMs, los secretos, el TLS, los datos y el almacenamiento.
- HAProxy, MariaDB, DNS y NFS son **SPOF**. No se ha demostrado continuidad ante caída de cualquiera de esas dependencias compartidas.
- La protección Apache de `uploads` **sí está instalada** en ambos WordPress, con evidencia aislada y productiva. Otras propuestas de Codex para firewall, systemd, HAProxy y backups **no se han aplicado a las VMs** y requieren validación separada.

## Antes de la defensa

La demostración deberá confirmar de nuevo el estado de los servicios, presentar balanceo y, en una ventana autorizada, reproducir una falla controlada con sus logs de salud. También hay que estar preparados para explicar el uso de NFS, MariaDB compartida, Docker Compose, `DOCKER-USER` y los puntos únicos de fallo. Este ensayo queda **para la etapa final de preparación**, una vez cerrado GitHub y resueltas las mejoras técnicas justificadas.

## Nota sobre E4

El ensayo de restauración de MariaDB (52 tablas) y la extracción de WordPress (10.313 archivos coincidentes por SHA-256) se hicieron por separado en laboratorio aislado. Son avances valiosos para la continuidad operacional de **Entrega 4**, pero no equivalen a restauración funcional integrada de WordPress + MariaDB, ni sustituyen los criterios técnicos de E3.
