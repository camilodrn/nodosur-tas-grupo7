# Plan de ensayo aislado de reproducibilidad — Nodo Sur E3

**Estado:** ensayo multicontenedor ejecutado el 21/10/2026. Se comprobaron arranque de cuatro contenedores, MariaDB healthy, SQL desde ambos WordPress, instalación ficticia, volumen compartido con SHA-256, persistencia tras reiniciar los cuatro servicios y reincorporación automática de Web1 a HAProxy, con 8/8 HTTP 200 y reparto 4/4 en la verificación posterior. Documento de apoyo a
[Entrega 3](ENTREGA3.md), [guía de reconstrucción](DESPLIEGUE-REPRODUCIBLE-E3.md)
y [rúbrica](RUBRICA-E3.md).

## Qué exige demostrar el criterio

El criterio literal de la rúbrica es **«Aplicación multicontenedor reproducible»**
(15 puntos). No debe confundirse con crear cinco VMs mediante un único
`docker compose up`. Nuestra arquitectura real usa **cuatro proyectos Compose
independientes**, uno por VM Docker (web1, web2, MariaDB y HAProxy); el quinto
host ofrece **BIND9 y NFS nativos**. Compose gestiona el motor local; la
orquestación/provisión de máquinas, red y NFS es externa.

### Evidencia existente

- Cuatro Compose productivos válidos con `docker compose config --quiet`.
- Huellas semánticas web1/web2 iguales entre Fedora y sus VMs.
- Servicios en marcha, MariaDB healthy y volumen histórico confirmado.
- Dos núcleos WordPress 7.1.3 iguales por huellas en 9.817 archivos de
  directorios auditados y archivos principales seleccionados.
- Proxy HTTPS con balanceo, `DOWN` y `UP` observados con caída autorizada.
- DNS, HTTPS, tienda y reparto nuevamente comprobados desde Fedora
  ([evidencia final](../evidencias/e3/validacion-integral-fedora-20261021.txt)).

**Límite:** lo anterior demuestra funcionamiento y coherencia de
configuraciones, pero no acredita por sí solo un despliegue desde cero.

## Evaluación de factibilidad — Fedora (21/10/2026)

Datos observados del operador:

- Docker Engine actual: `default` por `/var/run/docker.sock` (no Docker Desktop).
- Docker 29.9.1; Compose v5.5.1; 8 CPU y 16.485.978.112 bytes de RAM total.
- Aproximadamente 398 GiB libres en `/home` al medir.
- **Seis contenedores FurgoPlus running/healthy**, con puertos 127.0.0.1:18080
  y 127.0.0.1:18081 ocupados. **No detener ni tocar FurgoPlus.**
- Imágenes locales no equivalentes: `mariadb:12.3.3-noble` y
  `wordpress:7.1.2-php8.2-apache`. Deben obtenerse las imágenes específicas
  del ensayo; no etiquetar imágenes existentes para hacerlas parecer otras.
- La memoria **disponible ahora** y puerto 19090 aún requieren revisión
  antes de crear el proyecto.

**Preflight completado el 21/10/2026 (sin desplegar):** [registro de Docker Engine, memoria, puerto libre, secretos ficticios, `config --quiet`, cuatro servicios declarados y tres imágenes descargadas](../evidencias/e3/preflight-ensayo-fedora-20261021.txt). Los seis contenedores de FurgoPlus continuaban `healthy`. Ese era el alcance del preflight: el arranque y las respuestas posteriores quedaron acreditados en las pruebas siguientes.

## Hallazgo en escritura del volumen compartido (21/10/2026)

El [intento desde Fedora](../evidencias/e3/permisos-uploads-ensayo-fedora-20261021.txt) comprobó que web1 y web2 montan el mismo volumen local `nodosur-e3-ensayo_shared_uploads` con `RW=true`, **pero una escritura desde web1 como `www-data` falló con `Permission denied`**. Esto impidió la comparación de SHA-256 y el control final de FurgoPlus de ese bloque. **Causa confirmada:** ambos contenedores ejecutan la aplicación como `www-data` (UID/GID 33), mientras la raíz de `shared_uploads` es `root:root` (UID/GID 0), modo `755`; por ello se niega la escritura. El Compose de ensayo ahora **declara** un servicio de inicialización `uploads-init` que ajusta **solo** la raíz del volumen a `33:33` / `755` con `chown` no recursivo y sale, sin red. Ambos WordPress declaran `depends_on` con `service_completed_successfully`. **Corrección ejecutada y comprobada el 21/10/2026:** se validó Compose, se ejecutó solamente `uploads-init` (respuesta `UPLOADS_INIT_OK`) y luego ambos WordPress mostraron raíz de uploads `UID=33 GID=33 MODO=755`, `test -w` permitido como `www-data` y `docker compose exec -T` con exit 0 ([evidencia](../evidencias/e3/permisos-uploads-ensayo-fedora-20261021.txt)). La escritura real y lectura cruzada se completaron posteriormente ([SHA-256 coincidente](../evidencias/e3/volumen-compartido-ensayo-fedora-20261021.txt)); **no se probó** la ejecución automática de uploads-init en una instalación completamente nueva después del ajuste; las webs existentes no se recrearon. No `chmod 777`, ni cambios en el NFS productivo.

## Instalación WordPress ficticia ejecutada (21/10/2026)

Se versionó [`scripts/install-e3-lab-wordpress.sh`](../scripts/install-e3-lab-wordpress.sh). **Ejecutado exitosamente el 21/10/2026** ([evidencia](../evidencias/e3/wordpress-instalado-ensayo-fedora-20261021.txt)). El script exige `--permitir-instalacion`, comprueba contexto `default` y etiquetas `nodosur-e3-ensayo` en los cuatro contenedores, exige uploads escribible y genera una contraseña aleatoria de prueba en `~/.local/share/nodosur-e3-ensayo/wp_admin_password` con permiso 0600. Luego usa `wp_install()` únicamente en web1 para crear una instalación WordPress y su administrador ficticio en la base de datos **de ensayo**, sin mostrar la contraseña ni enviarla a Git. No cambia configuraciones productivas. Si la instalación falla, **no reintentar a ciegas**: WordPress podría haber creado tablas parcialmente.

Después se comprobaron HTTP 200 en ambos backends y estado persistente tras reiniciar **solo los contenedores del laboratorio** ([resultado](../evidencias/e3/persistencia-reinicio-ensayo-fedora-20261021.txt)). Ambos WordPress comparten tablas SQL y uploads, pero mantienen bind/volúmenes HTML separados y potencialmente claves de sesión distintas; **no se afirma coherencia de sesiones autenticadas**.

## Prueba de persistencia y recuperación ejecutadas (21/10/2026)

La [prueba de reinicio y comprobación posterior](../evidencias/e3/persistencia-reinicio-ensayo-fedora-20261021.txt) demostró MariaDB nuevamente `healthy`, conservación del título y administrador WordPress en ambas webs y **SHA-256 idéntico de uploads antes y después del reinicio**. El proxy volvió a responder HTTP 200. En las primeras seis peticiones de comprobación solo contestó Web2 (6/6), por lo que el script original terminó con error. **Sin reiniciar de nuevo**, los logs HAProxy evidenciaron Web1 `DOWN` por `Layer4 Connection refused` y posteriormente `UP` por `Layer7 HTTP 200`; los dos sitios devolvieron HTTP 200 y **ocho peticiones posteriores se repartieron 4/4**. Se confirma la reincorporación tras un intervalo de arranque, **sin medición formal del tiempo de recuperación**. El archivo temporal fue eliminado y los seis contenedores FurgoPlus siguieron `healthy`.

## Validador de persistencia utilizado (con espera corregida para futuras ejecuciones)

Se añadió [`scripts/validate-e3-lab-persistence.sh`](../scripts/validate-e3-lab-persistence.sh). Requiere contexto Docker `default`, comprueba la etiqueta `com.docker.compose.project=nodosur-e3-ensayo` de los cuatro contenedores y los nombres de sus volúmenes ficticios, verifica WordPress instalado y administrador presente desde ambos backends, crea un marcador temporal en uploads y compara su hash. A continuación **reinicia únicamente `database`, espera `healthy`, y reinicia `web1 web2 proxy`** dentro del mismo proyecto. Verifica nuevamente la instalación, HTTP 200, hash del marcador y participación de los dos backends, y elimina el archivo temporal con `trap`. No usa `down -v`, `up --force-recreate` ni operaciones contra FurgoPlus o VMs USM. La prueba ya se ejecutó con éxito en su verificación de persistencia, pero el chequeo inicial de balanceo fue demasiado temprano. El script se actualizó para esperar, con ventana limitada, a que **ambos** backends participen en respuestas HTTP 200. **Esta revisión del script no se ha reejecutado**: la recuperación se confirmó mediante comprobación posterior de solo lectura.

## Almacenamiento compartido aprobado (21/10/2026)

El [validador ejecutado desde Fedora](../evidencias/e3/volumen-compartido-ensayo-fedora-20261021.txt) **pasó**: web1/web2 montan el mismo volumen Docker en RW con UID/GID 33 y permisos 755, web1 creó un archivo ficticio, Web2 leyó el mismo contenido con SHA-256 idéntico, y el trap lo eliminó. Los cuatro contenedores de ensayo siguieron en ejecución (MariaDB `healthy`) y los seis contenedores FurgoPlus continuaron `healthy`. Esto **no acredita NFS** ni una instalación WordPress completada; el ensayo sigue sin WooCommerce.

## Validador de uploads ejecutado y aprobado

Se añadió [`scripts/validate-e3-lab-uploads.sh`](../scripts/validate-e3-lab-uploads.sh) para comparar montajes y escribir un único archivo ficticio desde web1, leer su SHA-256 desde ambos WordPress y limpiarlo con una trampa de salida. Cada `docker compose exec -T` recibe `</dev/null` para evitar que el proceso consuma la entrada de un script Bash invocado mediante heredoc. La herramienta se ejecuta desde un archivo versionado, no recrea ni detiene contenedores, y limita las operaciones al proyecto `nodosur-e3-ensayo`. La [salida de éxito](../evidencias/e3/volumen-compartido-ensayo-fedora-20261021.txt) acredita hashes iguales y limpieza del archivo ficticio.

## Prueba posterior: balanceo HTTP y conexiones SQL (21/10/2026)

La [evidencia del segundo control](../evidencias/e3/balanceo-sql-ensayo-fedora-20261021.txt) confirmó seis respuestas `302` alternando web1/web2 **3/3**, con redirección al instalador inicial de WordPress. Tanto web1 como web2 ejecutaron `SELECT 1` satisfactoriamente contra la MariaDB de ensayo usando el usuario `www-data` y secreto ficticio sin mostrar. **Ese bloque histórico** terminó sin imprimir los pasos de uploads ni estado de FurgoPlus; esos controles se completaron en pruebas posteriores. El validador versionado usa `</dev/null` para evitar consumos involuntarios del heredoc.

## Primer arranque ejecutado en Fedora (21/10/2026)

El [registro del primer arranque](../evidencias/e3/primer-arranque-ensayo-fedora-20261021.txt) confirma **cuatro contenedores levantados desde el Compose de laboratorio**, con MariaDB healthy, redes y cuatro volúmenes creados y puerto local 127.0.0.1:19090; la respuesta HTTP inicial fue **302**. Los seis contenedores FurgoPlus seguían healthy. **En ese primer arranque todavía no estaban comprobados** el balanceo, SQL, la instalación del CMS ni la lectura de uploads; todos ellos se probaron en controles posteriores. Esta comprobación no modifica datos productivos.

## Definición del ensayo utilizada en Fedora

Archivos exclusivos del ensayo:
[`compose/e3-lab/compose.yaml`](../compose/e3-lab/compose.yaml) y
[`compose/e3-lab/haproxy.cfg`](../compose/e3-lab/haproxy.cfg).

Al ejecutarse únicamente en Fedora con proyecto `-p nodosur-e3-ensayo`,
estos archivos definen **cuatro contenedores**:

- `mariadb:10.11`, con datos y contraseñas exclusivamente de laboratorio.
- Dos `wordpress:7.1.3-php8.3-apache`, versión efectiva alineada pero
  **imagen diferente al tag histórico declarado en producción**.
- `haproxy:3.2.23-alpine`, con **HTTP de laboratorio sin TLS**, no el
  certificado ni la configuración pública de VM308.
- Dos volúmenes HTML separados, un volumen de uploads compartido (Docker
  local **no NFS**) y un volumen independiente de MariaDB.
- Una red frontal y una red interna de base de datos propias del proyecto.
- Solo un puerto publicado en Fedora: **127.0.0.1:19090**, a validar libre.
  No se publican las webs ni el puerto 3306 del DB.
- Contraseñas aleatorias de ensayo en archivos privados fuera de Git;
  `WORDPRESS_DB_PASSWORD_FILE` y `MARIADB_*_PASSWORD_FILE` leen secretos
  desde montajes de Compose sin colocarlos en `docker inspect` como texto.
- La misma configuración Apache de prohibición PHP en uploads montada
  con lectura sola, sin copiar configuraciones privadas.

**No despliega WooCommerce ni restaura el WordPress productivo.** Al iniciar
desde volúmenes nuevos, WordPress mostrará el instalador inicial hasta que
se configure con **datos ficticios**. Los health checks HTTP aceptan 200/302
durante la inicialización, a diferencia del `HEAD / = 200` productivo.

**No ejecutar `docker compose down -v`**, ni borrar recursos de otros
proyectos. Documentar toda creación/remoción de recursos del ensayo, con
revisión explícita de nombres y etiquetas antes de limpiar.

### Preflight sin crear contenedores

1. Traer la nueva rama de cierre con `git fetch` y
   `git merge --ff-only origin/e3/cierre-tecnico`, solo desde el clon Fedora
   limpio; nunca sincronizar los checkouts de VMs para ejecutar este ensayo.
2. Revisar `free -h`, estado y contexto Docker, puerto TCP 19090 y que no
   exista proyecto etiquetado `nodosur-e3-ensayo`.
3. Crear **solo una vez** dos contraseñas ficticias con `umask 077` en
   `~/.local/share/nodosur-e3-ensayo`, directorio **0700**, sin mostrar valores.
   **Detalle de Compose con secretos desde `file`:** el contenedor WordPress
   ejecuta PHP como `www-data`, que necesita leer `db_password`. Docker Compose
   monta el archivo de origen y no remapea UID/GID o `mode` para secretos
   `file`. Después de crear las contraseñas, dar modo **0444 únicamente al
   archivo ficticio `db_password`**, dejando el directorio host 0700 y el
   archivo privado `db_root_password` en 0600. La carpeta 0700 impide a
   usuarios locales no autorizados atravesar el directorio, aunque `db_password`
   sea legible dentro de los contenedores con el secreto montado. No aplicar
   esta práctica a secretos productivos sin un diseño de permisos propio.
4. Verificar con `stat` solo permisos y rutas, sin imprimir las contraseñas.
   Luego exportar `NODOSUR_E3_LAB_SECRETS` con esa ruta y ejecutar
   `docker compose -p nodosur-e3-ensayo -f compose/e3-lab/compose.yaml config --quiet`.
5. Confirmar que `docker compose config` valida; aún **no** descargar imágenes
   ni ejecutar `up` hasta evaluar el resultado de la inspección.

### Puesta en marcha propuesta tras preflight satisfactorio

En una siguiente fase **solo con recursos suficientes y verificación de puertos**:
`docker compose -p nodosur-e3-ensayo -f compose/e3-lab/compose.yaml pull`
seguido de `up -d` (mismo proyecto). Registrar errores/reintentos; no asumir
que Docker Hub o la instalación inicial responderán correctamente sin probarlo.

Comprobar `docker compose ... ps`, base saludable, resolución de servicios
por nombre dentro de las redes, respuestas HTTP locales y cabecera
`X-NodoSur-Lab-Backend`. La instalación WordPress necesitará datos
**únicamente ficticios**; no introducir contraseñas de USM ni importar datos
productivos. No confundir este ensayo con la reconstrucción de cinco VMs.

## Prueba propuesta: nuevo entorno aislado

El ensayo deberá desplegar una **copia de laboratorio con datos ficticios**
mediante Compose, reutilizando imágenes y patrones de arquitectura, sin
interferir con las VMs productivas. No sustituye una recuperación completa de
los datos originales.

### Etapa 0 — verificar factibilidad en Fedora (solo lectura)

- Determinar contexto Docker efectivo (Docker Engine vs Docker Desktop), versión
  de Compose, memoria/CPU del daemon, espacio libre y contenedores existentes.
- Verificar disponibilidad de imágenes y elegir un proyecto Compose
  **exclusivo**, no usado por producción.
- No ejecutar todavía `docker compose up`.

### Etapa 1 — preparar definición segura

- Definir proyecto y nombres de redes, volúmenes y contenedores **distintos**
  de `nodosur-db-staging`, `nodosur-web1`, `nodosur-web2` y `nodosur-haproxy`.
- Usar puertos publicados solo en `127.0.0.1`, tras verificar que están libres.
- Mantener secretos **temporales y privados** fuera del repositorio; no imprimir
  contraseñas ni incorporarlas a Git.
- Usar **datos de prueba**. No copiar el volumen
  `nodosur-db-staging_db_stage_data`, ni `wp-config.php` real, ni certificados
  con clave privada, ni exportaciones NFS de producción.
- Aclarar expresamente cualquier sustitución: por ejemplo, un volumen local
  compartido **no demuestra montaje NFS real**; un HAProxy de laboratorio con
  certificado distinto no demuestra confianza TLS en el laboratorio USM.
- Validar Compose y todas las rutas/variables antes de crear contenedores.

### Etapa 2 — evidencia de despliegue

Solo si la etapa previa resulta satisfactoria:

- Iniciar únicamente el proyecto de laboratorio.
- Verificar contenedores, salud DB, rutas HTTP de los dos WordPress, proxy y
  persistencia **con datos ficticios**.
- Demostrar que el proyecto mantiene su estado de prueba en un reinicio
  controlado del propio laboratorio, si es necesario y seguro.
- Capturar salidas mínimas con fecha, `docker compose ps`, resultados HTTP,
  montajes y nombre de volumen **de laboratorio**, sin secretos.
- Limpiar únicamente los recursos marcados y creados por ese proyecto, con
  revisión explícita antes de borrar volúmenes. Nunca usar `docker volume prune`
  ni `docker compose down -v` desde carpetas productivas.

### Etapa 3 — aceptación y límites

| Evidencia | Éxito mínimo | Límite a declarar |
|---|---|---|
| Configuración | Compose válido y dependencias explícitas | No crea VLAN o VM |
| Contenedores | Servicios de laboratorio ejecutándose | No son los de producción |
| Base de datos | Salud y volumen de ensayo persistente | No restauró BD histórica |
| Dos webs | WordPress responde por cada backend | No certifica plugins o clientes reales |
| Proxy | Encaminamiento y health checks de laboratorio | No certifica TLS público |
| Almacenamiento | Compartición o volumen de ensayo verificado | No prueba NFS del iLab |
| Seguridad | Secretos temporales fuera de Git y binds acotados | No reemplaza firewall de VMs |

**Si no hay recursos o el laboratorio aislado no se completa, no afirmar que
se ejecutó.** Para la defensa presentar honestamente la reproducibilidad
**por host** ya validada y explicar la provisión externa necesaria.

## Prohibiciones productivas

No ejecutar en VM279 acciones capaces de renombrar, borrar o recrear
`nodosur-db-staging_db_stage_data`. No ejecutar `git pull/reset/clean` ni
recrear contenedores en VM263 y VM310 con sus cambios locales de Compose.
No modificar reglas, DNS, TLS, NFS o systemd para perseguir una puntuación
sin un defecto observado y un plan de reversión.
