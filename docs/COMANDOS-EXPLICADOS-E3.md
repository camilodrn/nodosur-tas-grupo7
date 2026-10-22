# Comandos explicados paso a paso — Nodo Sur, Entrega 3

**Guía de aprendizaje para los cuatro integrantes · 22/10/2026**

[Guía de estudio individual](GUIA-ESTUDIO-INDIVIDUAL-E3.md) · [Tarjeta de comandos por VM](TARJETA-COMANDOS-E3.md) · [Mapa de archivos y reglas](MAPA-CONFIGURACIONES-E3.md)

**Propósito:** entender qué significa cada comando que aparece en los documentos de E3, qué hacen sus opciones, dónde se ejecutan, qué resultado esperar y qué peligro tienen. **No es una nueva configuración ni una modificación de infraestructura.** La evaluación será en el puesto y el profesor puede pedirle cualquier comprobación a cualquier integrante.

## 1. Una aclaración esencial: ¿qué significa «solo lectura»?

**No existe un prefijo mágico que convierta cualquier comando en solo lectura.**

- Se considera una **consulta de solo lectura** por el tipo de operación: por ejemplo, ls lista archivos, findmnt muestra montajes, iptables -S lista reglas y git status describe el estado.
- **sudo** permite ejecutar con privilegios administrativos. **NO significa modo seguro ni solo lectura.** sudo cat puede leer material privado; sudo rm puede borrar.
- **docker exec** ejecuta un comando dentro de un contenedor. **NO es solo lectura por sí mismo.** docker exec ... ls consulta; docker exec ... rm modifica o borra.
- **-f NO significa siempre «forzar»**: en docker compose -f indica archivo Compose; en docker inspect -f indica plantilla de formato; en rm -f sí significa forzar la eliminación.
- **:ro**, **read_only: true** o **RW=false** indican características de montaje de archivos o contenedores. Es una propiedad de la configuración o estado de Docker; no hacen que otros comandos sean de lectura.
- **--** puede separar las opciones de los argumentos. En rm -f -- archivo evita interpretar un nombre de archivo que empiece con guion como una opción, pero el rm sigue **borrando**.
- **test -f** y **test -s** solo comprueban existencia/tipo o contenido no vacío; no cambian el archivo. No usar cat para probar si existe un secreto.

**Regla de evaluación:** antes de pulsar Enter, poder contestar «¿Qué servicio/VM consulta? ¿Qué va a leer o cambiar? ¿Podría mostrar una contraseña? ¿Cómo interpretaré el resultado?».

## 2. Entender la estructura de una orden de Linux

Ejemplo:

~~~bash
sudo docker exec nodosur-web1 ls /var/www/html/wp-content
~~~

| Fragmento | Qué significa |
|---|---|
| sudo | Solicita ejecutar lo siguiente con privilegios de otro usuario, normalmente root. |
| docker | Programa de administración de contenedores. |
| exec | Subcomando que ejecuta algo dentro de un contenedor ya existente. |
| nodosur-web1 | Contenedor elegido, **no** es el nombre de la VM. |
| ls | Comando que se ejecuta dentro del contenedor; lista archivos. |
| /var/www/html/wp-content | Directorio de WordPress dentro del contenedor. |

**Efecto:** consulta el contenido; **no** crea ni detiene contenedores. **Error típico:** ejecutar la orden en VM310, donde el contenedor se llama nodosur-web2, y concluir erróneamente que WordPress está caído.

Otros símbolos de terminal:

| Símbolo | Qué hace | Precaución |
|---|---|---|
| / | Separa directorios; /etc o /srv son rutas absolutas. | Las rutas de host y contenedor pueden ser distintas. |
| . | Directorio actual; también aparece en ./archivo. | No es sinónimo de repositorio Git. |
| .. | Directorio superior. | cd .. cambia la carpeta actual. |
| ~ | Tu directorio personal, según usuario efectivo/contexto. | ~ de root no es ~ del estudiante. |
| # | Inicia un comentario en un script Bash cuando corresponde. | No forma parte del comando que ejecuta Bash. |
| comillas simples '...' | Mantienen el texto literal y evitan expansiones de shell. | Útiles para plantillas de docker inspect y patrones grep. |
| comillas dobles "..." | Agrupan texto; pueden permitir expansión de variables. | No sirven para ocultar contraseñas de historial de shell. |
| \ al final de línea | Continúa un comando largo en la línea siguiente. | No agregar espacios después de la barra. |
| opción corta -x | Parámetro abreviado de un programa. | Su significado depende del programa. |
| opción larga --nombre | Parámetro descriptivo de un programa. | No hay significado universal. |
| Barra vertical (pipe) | Envía salida estándar de un programa al siguiente. Ejemplo: ls seguido de una barra vertical y head. | El segundo comando puede filtrar y ocultar parte de la salida. |
| > | Redirige salida a un archivo **sobrescribiéndolo/truncándolo**. | Puede destruir contenido previo; NO usar en evaluación. |
| >> | Agrega salida al final de un archivo. | Modifica el archivo; NO es solo lectura. |
| < | Da un archivo como entrada estándar. | Leer entrada no implica modificar el archivo, pero el programa receptor podría cambiar otras cosas. |
| </dev/null | Entrega una entrada vacía, útil cuando docker compose exec no debe consumir el resto del script. | **No vuelve seguro ni solo lectura** el comando. |
| 2>&1 | Envía errores al mismo flujo que la salida normal. | Puede mezclar o mostrar mensajes sensibles si no filtras. |
| && | Ejecuta el segundo comando solo si el primero terminó correctamente. | Si el segundo modifica, igualmente modificará. |
| ; | Separa comandos; ejecuta el siguiente aunque el anterior falle. | No es una condición de seguridad. |
| || true | Hace que una consulta fallida no detenga el bloque. | Puede **ocultar un fallo real**; no usar para dar por buena una prueba. |

**Sobre el pipe:** en texto se representa como la barra vertical que aparece entre comandos, por ejemplo:

~~~bash
sudo docker exec nodosur-web1 ls /var/www/html/wp-content | head
~~~

El resultado de ls pasa a head, que muestra una porción inicial. **El listado fue truncado intencionalmente**: no asumir que contiene todos los archivos.

## 3. Siempre de lo simple a lo avanzado

Para que el profesor vea dónde están los archivos, la opción más simple suele ser suficiente. Usar la larga si es necesario comprobar propiedades específicas.

| Pregunta | Primero, más simple | Después, si solicita prueba adicional |
|---|---|---|
| ¿Quién soy y dónde estoy? | whoami; pwd; hostname | ip -br addr para interfaces/IP |
| ¿Dónde está el código Web1? | sudo ls /srv/nodosur/web1/html | sudo docker exec nodosur-web1 ls /var/www/html/wp-content |
| ¿NFS está montado en la web? | findmnt -M /srv/nodosur/nfs/uploads | findmnt -M ... -o SOURCE,FSTYPE,TARGET,OPTIONS |
| ¿Qué expone NFS en el servidor? | sudo exportfs -v | Leer /etc/exports o /etc/exports.d si ahí está declarado |
| ¿Corre WordPress? | sudo docker ps | docker inspect -f '{{.State.Status}}' CONTENEDOR y HTTP |
| ¿Qué dice la unidad systemd? | sudo systemctl cat nodosur-web1.service | sudo systemctl show ... -p WorkingDirectory -p ExecStart |
| ¿Qué DNS devuelve el dominio? | dig @10.33.195.205 nodosur07.tas A +short | SOA UDP/TCP y zona con named-checkconf |
| ¿Qué regla protege el backend? | sudo iptables -S DOCKER-USER | sudo iptables -nvL DOCKER-USER, para contadores |
| ¿Es válida la configuración Apache? | sudo docker exec nodosur-web1 apache2ctl -t | Revisar el archivo Apache de uploads y montaje |
| ¿Cómo se configura HAProxy? | Ver compose/proxy/haproxy.prod.cfg en Git | Validar la configuración cargada con haproxy -c |
| ¿Qué volumen conserva la DB? | sudo docker volume ls --filter name=nodosur-db-staging_db_stage_data | docker inspect -f limitado a sus montajes |

**No reemplazar una comprobación de estado por otra distinta.** Por ejemplo, docker ps muestra que el proceso del contenedor se ejecuta; curl HTTP 200 comprueba que una ruta responde; un healthcheck de DB no prueba todo WooCommerce.

## 4. Comandos explicados por familias

### 4.1 Carpetas: ls, pwd, cd, grep, head, sed

~~~bash
pwd
ls
ls -lah /srv/nodosur/web1/html
ls /srv/nodosur/web1/html | head
sudo sed -n '1,80p' /etc/nodosur/apache/nodosur-uploads.conf
~~~

- **pwd**: imprime la carpeta actual. **cd**: cambia la carpeta actual de la terminal; no edita sus archivos. **ls**: lista archivos.
- **ls -l**: formato detallado (permisos, dueño, tamaño, fecha). **-a**: incluye nombres ocultos. **-h**: tamaños legibles. Juntas, **-lah**.
- **head**: muestra las primeras diez líneas por defecto, no el árbol completo. **tail -n 15**: últimas quince líneas.
- **sed -n '1,80p' archivo**: pide a sed no imprimir todo automáticamente (**-n**) y mostrar las líneas **1 a 80** (**p**, de print). En este uso **no edita** el archivo. **sed -i sí lo modifica** y no debe confundirse.
- **grep -n**: busca texto mostrando número de línea. **grep -F**: interpreta patrón como texto literal. **grep -i**: ignora mayúsculas. **grep -E**: permite expresiones regulares extendidas. **grep -A 8 -B 2**: muestra ocho líneas después y dos antes de cada coincidencia.
- **grep sin coincidencias** suele terminar con código 1: no significa necesariamente que el servidor haya fallado.
- **Nunca usar sed ni cat para imprimir wp-config.php, contraseñas o el PEM privado**: son comandos de lectura pero igual pueden divulgar secretos.

Ejemplo real en VM268:

~~~bash
sudo grep -n -A 8 -B 2 'zone "nodosur07.tas"' /etc/bind/named.conf.local
~~~

Lee el archivo de configuración de zonas de BIND9; busca literalmente el encabezado del bloque de zona y su contexto. Ahí se añadió la regla **allow-transfer { none; };**, no en el archivo de registros DNS.

### 4.2 NFS: exportfs, findmnt y cómo relacionar las tres rutas

**En VM268, servidor NFS:**

~~~bash
sudo exportfs -v
sudo ls -ld /srv/nodosur/uploads
~~~

- **exportfs -v**: muestra exports NFS y opciones conocidas por el servidor. **-v** significa verbose/detallado. **Sin -a, -r ni -u** es una consulta, no una orden para cambiar exportaciones.
- **ls -ld directorio**: **-l** detalles y **-d** información sobre el propio directorio, en vez de listar su contenido.

**En Web1 o Web2, hosts clientes:**

~~~bash
findmnt -M /srv/nodosur/nfs/uploads
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,TARGET,OPTIONS
~~~

- **findmnt**: muestra sistemas de archivos montados.
- **-M**: selecciona exactamente ese **punto de montaje**. No monta ni desmonta nada.
- **-o**: elige las columnas mostradas: **SOURCE** (origen, por ejemplo VM268), **FSTYPE** (tipo, nfs4), **TARGET** (punto local) y **OPTIONS** (propiedades del montaje).

**Dentro del WordPress** la ruta es /var/www/html/wp-content/uploads. Su correspondencia con el host se comprueba con Docker:

~~~bash
sudo docker inspect nodosur-web1 -f \
  '{{range .Mounts}}{{if eq .Destination "/var/www/html/wp-content/uploads"}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}{{end}}'
~~~

Desglose de la parte entre comillas, que es una **plantilla de formato de Docker** (no un script Bash):

| Parte | Significado |
|---|---|
| -f | Equivale a --format: selecciona qué información imprimir. |
| .Mounts | Lista de montajes detectados en el contenedor. |
| range .Mounts ... end | Recorre los montajes uno por uno. |
| if eq .Destination "...uploads" | Solo muestra el montaje cuyo destino coincide con esa ruta exacta. |
| .Source | Carpeta de origen del montaje en el host Docker. |
| .Destination | Carpeta visible dentro del contenedor. |
| .RW | Indica si Docker montó ese recurso con permiso lectura/escritura, true/false. |
| -> y RW= | Texto decorativo para leer mejor la salida. |

**Más corto si el profesor solo pide la ruta:** se puede mostrar el archivo compose/web1/compose.yaml o compose/web2/compose.yaml en Git, donde aparece source y target. Pero eso enseña la **intención del YAML**, no el montaje efectivo: para demostrar lo real, usar findmnt y docker inspect.

**Archivo de configuración NFS que falta confirmar:** el export y la ruta están comprobados; el archivo exacto del servidor se debe ubicar con exportfs -v y una búsqueda de solo lectura en /etc/exports o /etc/exports.d. En los clientes, revisar /etc/fstab o unidades de montaje; **no afirmar que el grupo editó un archivo específico si no consta**. Ver [mapa de archivos](MAPA-CONFIGURACIONES-E3.md).

### 4.3 Docker: ps, exec, inspect y compose

~~~bash
sudo docker ps
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
sudo docker exec nodosur-web1 ls /var/www/html/wp-content
sudo docker exec nodosur-web1 apache2ctl -t
sudo docker inspect -f '{{.State.Status}}' nodosur-web1
~~~

- **docker ps**: lista contenedores en ejecución; no los enciende ni detiene.
- **--format**: decide qué columnas mostrar para evitar datos innecesarios.
- **docker exec**: ejecuta el subcomando dentro del contenedor **existente**. Su efecto depende de ese subcomando; ls y apache2ctl -t son consultas/comprobaciones.
- **docker inspect -f '{{.State.Status}}'**: consulta el estado del contenedor (por ejemplo running), mostrando solo ese campo. **Es preferible a un inspect completo**, que puede mostrar variables o datos sensibles.
- **-u www-data** en docker exec: ejecuta el comando como ese usuario dentro del contenedor; **no garantiza solo lectura**.
- **-T** en docker compose exec -T: no asigna terminal interactiva (TTY); útil para scripts. **No significa prueba, seguridad ni solo lectura**.

**Compose por rol:** en VM263 se usa este archivo, en VM310 otro; no ejecutar todos en un host.

~~~bash
# SOLO en VM263, estando en el checkout instalado:
sudo docker compose -f compose/web1/compose.yaml config --quiet
~~~

- **compose**: trabaja con definición de servicios Docker del host.
- **-f compose/web1/compose.yaml**: elige qué YAML leer. **Aquí -f significa file, NO force.**
- **config**: procesa/valida el modelo Compose, sus servicios y referencias.
- **--quiet**: no imprime la configuración completa. Es útil para evitar mostrar valores innecesarios.
- **No arranca** contenedores ni certifica disponibilidad, persistencia, red o secretos correctos. Tampoco crea VMs.
- **docker compose up -d** sí intenta crear/iniciar servicios: **no usarlo para una pregunta que solo pide ver configuración**.

### 4.4 systemd: cat, show, is-active

~~~bash
sudo systemctl is-active nodosur-web1.service
sudo systemctl cat nodosur-web1.service
sudo systemctl show nodosur-web1.service -p WorkingDirectory -p ExecStart -p ActiveState
~~~

- **is-active**: responde si la unidad figura activa. Puede mostrar active, inactive, etc.
- **cat**: muestra el contenido del archivo de unidad cargado y sus overrides; **no modifica** la unidad.
- **show**: consulta propiedades; **-p** selecciona las que quieres ver.
- **WorkingDirectory**: carpeta desde la cual systemd ejecuta sus comandos.
- **ExecStart**: instrucción configurada para iniciar ese servicio.
- **ActiveState**: estado de la unidad systemd.
- **systemctl restart, stop, start, enable, disable o daemon-reload SÍ alteran estado/configuración**. No se necesitan para explicar una unidad.

**Caso particular de Nodo Sur:** en Web1 y MariaDB la unidad instalada utiliza un directorio bajo /home/tas_revision/nodosur-tas-grupo7. **No borrar ese HOME**, aunque la cuenta de revisión E2 esté caducada. Una unidad oneshot con RemainAfterExit=yes puede figurar activa aunque el contenedor no esté sano: comprobar docker ps/inspect y HTTP.

### 4.5 DNS: dig y named-checkconf

~~~bash
dig @10.33.195.205 nodosur07.tas A +short
dig @10.33.195.205 nodosur07.tas SOA +noall +answer
sudo named-checkconf -z
sudo named-checkzone nodosur07.tas /etc/bind/db.nodosur07.tas
~~~

- **dig**: consulta DNS. **@10.33.195.205** escoge específicamente BIND9 de VM268.
- **nodosur07.tas**: nombre consultado. **A** pide dirección IPv4; **SOA** pide los datos de autoridad de la zona.
- **+short**: salida reducida, normalmente solo valores de respuesta.
- **+noall +answer**: oculta la mayoría de secciones e imprime la respuesta.
- **+tcp**: usa TCP para la consulta; si se omite, dig normalmente usa UDP para una consulta A o SOA.
- **named-checkconf -z**: valida sintaxis y prueba carga de zonas desde archivos; no cambia la configuración en ejecución.
- **named-checkzone**: valida la zona especificada contra su archivo de registros. **No es un comando para editar el archivo**.

Si dig devuelve la IP del proxy, eso **no prueba** que el navegador pueda entrar: todavía faltan ruta, puerto, TLS, HTTP, proxy y aplicaciones.

### 4.6 HTTP/HTTPS: por qué curl puede verse tan largo

Primero, una consulta corta desde Fedora con VPN y resolución funcional:

~~~bash
curl -I http://nodosur07.tas/
~~~

- **curl**: hace una solicitud web.
- **-I**: pide solo cabeceras mediante el método HTTP HEAD. Puede comportarse distinto de un GET real.
- **Esperado históricamente:** respuesta HTTP 301 y cabecera Location hacia HTTPS. Si el proxy del sistema, VPN o resolución local interfiere, usar la variante controlada que sigue.

Versión larga usada en E3, que **evita depender del DNS local del cliente**:

~~~bash
curl --noproxy '*' -sSI --resolve nodosur07.tas:80:10.33.195.194 \
  http://nodosur07.tas/ | grep -Ei '^(HTTP/|location:)'
~~~

| Parte | Significado |
|---|---|
| --noproxy '*' | Para esta consulta, no usar un proxy HTTP configurado en el cliente. Las comillas evitan que Bash expanda *. |
| -s | Silent: oculta progreso/ruido. |
| -S | Show error: mantiene mensajes de error si ocurre un fallo. |
| -I | Usa HEAD para solicitar las cabeceras, no descargar el cuerpo. |
| -sSI | Forma abreviada de -s -S -I agrupadas. |
| --resolve dominio:80:IP | Para ese destino y puerto, conecta a esa IP pero conserva el nombre de dominio de la URL. **No prueba que la resolución DNS habitual del equipo funcione.** |
| \ al final | Continúa en la línea siguiente la misma orden. |
| pipe a grep | Filtra la salida, mostrando solo las cabeceras que coinciden. |
| grep -E | Interpreta el patrón como expresión regular extendida. |
| grep -i | Busca sin distinguir mayúsculas/minúsculas. |
| ^(HTTP/|location:) | Muestra líneas que empiezan con HTTP/ o location:. El signo ^ significa inicio de línea y | significa alternativa dentro del patrón. |

**Para HTTPS con certificado autofirmado**:

~~~bash
curl --noproxy '*' -ksSI \
  --resolve nodosur07.tas:443:10.33.195.194 \
  https://nodosur07.tas/ | grep -Ei '^(HTTP/|x-nodosur-backend:)'
~~~

- **-k o --insecure**: ignora la validación de confianza del certificado en curl. **No garantiza autenticidad** del servidor; solo sirve para diagnosticar conectividad con TLS autofirmado.
- **443**: HTTPS en el proxy. El navegador no se conecta por 443 directamente a WordPress.
- **X-NodoSur-Backend**: respuesta del proxy para identificar el backend que atendió. Repetir consultas permite observar reparto cuando ambos están disponibles.
- **-s** puede ocultar información de progreso; **-S** mantiene los errores visibles.
- **GET vs HEAD:** la comprobación corta con -I es suficiente para cabeceras; para evaluar una ruta de aplicación completa, la guía de E3 también usa solicitudes GET que comprueban códigos/recursos.

**Para imprimir solo código HTTP sin cuerpo** (desde VM308 a un backend autorizado):

~~~bash
curl --noproxy '*' -sS -o /dev/null -w '%{http_code}\n' \
  -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' \
  http://10.33.199.58:18081/
~~~

- **-o /dev/null**: descarta el cuerpo descargado, pero **no borra archivos** ni modifica /dev/null.
- **-w**: escribe la información solicitada tras la transferencia; **%{http_code}** es el código HTTP obtenido y **\n** agrega salto de línea.
- **-H**: agrega una cabecera a la solicitud. En este caso Host y X-Forwarded-Proto simulan datos esperados por WordPress detrás de HAProxy.
- **--connect-timeout 5** y **--max-time 15**, cuando se incluyen, limitan cuánto espera curl al conectar y en total.
- **HTTP 000**, mostrado por -w cuando curl no obtuvo respuesta HTTP, **no es un código HTTP del servidor**. Revisar el código de salida de curl y su error.

### 4.7 Firewall: iptables y UFW

~~~bash
sudo iptables -S DOCKER-USER
sudo iptables -nvL DOCKER-USER
sudo ufw status numbered
~~~

- **iptables -S**: lista reglas en sintaxis parecida a comandos de configuración. No modifica.
- **DOCKER-USER**: cadena que permite filtrar tráfico que atraviesa reglas de Docker en el host.
- **-L**: lista reglas; **-n** evita resolver nombres; **-v** añade detalles como contadores. **-nvL** agrupa esas tres opciones.
- **ufw status numbered**: presenta reglas UFW vigentes con índices, sin editarlas.
- **iptables -A, -I, -D y -F SÍ modifican reglas** (añadir, insertar, borrar, vaciar). UFW allow/deny/delete también modifica.
- En Web1 y Web2 la regla activa bloquea conexiones a puertos internos desde orígenes diferentes a IP de HAProxy 10.33.199.61. Se observó HTTP 200 desde proxy y timeout desde VM268; **no atribuir un timeout a una regla concreta sin evidencias adicionales**.

**¿Dónde está el archivo de las reglas?** En el repositorio hay una plantilla: configs/firewall/nodosur-docker-firewall.sh. El servicio real observado en ambas webs es nodosur-docker-firewall.service. Para comprobar el **script instalado que ejecuta**, consultar:

~~~bash
sudo systemctl cat nodosur-docker-firewall.service
sudo systemctl show nodosur-docker-firewall.service -p ExecStart
~~~

### 4.8 MariaDB: volumen y estado sin leer datos de clientes

~~~bash
sudo docker inspect nodosur-db-staging \
  -f 'Estado={{.State.Status}} Salud={{.State.Health.Status}}'

sudo docker inspect nodosur-db-staging \
  -f '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}} -> {{.Destination}}{{end}}{{end}}'
~~~

- **.State.Status**: estado del contenedor, por ejemplo running.
- **.State.Health.Status**: estado del healthcheck, por ejemplo healthy.
- **.Mounts**: montajes del contenedor; se filtra el destino **/var/lib/mysql**.
- **.Name**: nombre del volumen Docker montado allí, en el caso productivo **nodosur-db-staging_db_stage_data**.
- **Volumen Docker ≠ archivo de SQL dentro de Git.** El volumen persiste los datos reales y no se debe recrear o borrar para mostrarlo.
- **docker volume ls** lista; **docker volume rm** borra; **docker compose down -v** puede borrar volúmenes del proyecto. No ejecutar esos comandos destructivos.

### 4.9 Integridad de archivos: sha256sum

~~~bash
sudo sha256sum /srv/nodosur/uploads/woocommerce-placeholder-768x768.webp
~~~

- **sha256sum** lee el archivo y calcula una huella digital. No edita el archivo.
- Si la huella de los bytes obtenidos desde Web1 y Web2 coincide con la del archivo NFS, existe evidencia de que ambos entregaron el mismo contenido.
- Un hash coincidente **no prueba** que todas las sesiones WooCommerce ni pedidos concurrentes sean coherentes.
- Si el archivo no existe, no crear uno productivo por improvisación; mostrar la evidencia E3 ya registrada.

### 4.10 Git: consultas, descargas y comandos que SÍ cambian archivos

~~~bash
git status -sb
git branch --show-current
git log -1 --oneline
git remote -v
git diff --stat
~~~

- **git status -sb**: estado breve de rama/seguimiento; no modifica archivos.
- **git branch --show-current**: rama actual.
- **git log -1 --oneline**: último commit resumido.
- **git remote -v**: URL(s) del remoto.
- **git diff --stat**: resumen de diferencias **no preparadas**. **git diff --cached** consulta diferencias en el índice (staging). No confundir índice con working tree.

**No son consultas puras:**

| Comando | Efecto |
|---|---|
| git fetch origin | Descarga objetos y actualiza referencias locales de ramas remotas; no cambia normalmente archivos del working tree. |
| git pull --ff-only origin main | Integra cambios en la rama local y **puede modificar archivos**; rechaza merges que no sean fast-forward. |
| git switch main | Cambia de rama y **puede modificar los archivos** del working tree. |
| git restore --source=HEAD --staged --worktree -- . | Reemplaza archivos versionados e índice desde HEAD; **puede descartar cambios locales**. Solo se usó tras diagnóstico y copia de seguridad, nunca hacerlo a ciegas. |
| git add / git commit / git push | Preparan, registran o publican cambios. |
| git reset --hard / git clean | Pueden descartar cambios y borrar archivos sin recuperar fácilmente. **No usar en VMs productivas**. |

**Caso real de esta entrega:** Fedora terminó en rama main y origin/main en commit 2729bf5, sin cambios pendientes. GitHub y el clon se sincronizaron. **No hacer pull en las VMs del iLab** solo porque GitHub tenga un commit más reciente: las VMs Web1/Web2 conservan cambios locales de Compose probados y sus unidades systemd dependen de rutas históricas.

---

## 5. Leer una salida y explicar su límite

| Si observas… | Puedes afirmar… | NO puedes afirmar… |
|---|---|---|
| docker ps dice Up | El contenedor está ejecutándose. | Que WordPress y compras funcionan plenamente. |
| systemctl is-active dice active | La unidad figura activa. | Que el proceso o WordPress siguen sanos, especialmente oneshot. |
| dig responde 10.33.195.194 | BIND devolvió la IP de HAProxy. | Que HTTPS o WooCommerce funcionan. |
| findmnt dice nfs4 desde 10.33.199.59 | El host web tiene un montaje NFS de VM268. | Que un archivo nuevo se escribe bien o que todos los clientes tienen permisos. |
| docker inspect .RW dice true | Docker considera ese montaje de lectura/escritura. | Que permisos de Linux/NFS permitan escribir como www-data. |
| curl -k devuelve HTTP 200 | Hubo respuesta HTTPS satisfactoria sin validar CA. | Que identidad TLS quedó comprobada por una CA confiable. |
| HEAD / devuelve 200 en HAProxy | El chequeo HTTP responde y puede contribuir al estado UP. | Que DB, NFS, carrito o checkout estén totalmente sanos. |
| sudo iptables -S muestra DROP | Existe una regla de descarte registrada. | Que se haya aplicado a un paquete particular sin correlación. |
| sha256sum de NFS/Web1/Web2 coincide | En esa prueba las tres copias tuvieron bytes iguales. | Que el sistema entero sea replicado y redundante. |
| git status está limpio en Fedora | No hay cambios rastreados pendientes en ese checkout. | Que las VMs estén ejecutando el mismo commit. |

## 6. Cómo practicar con poco tiempo

**Primera vuelta:** cada integrante toma cinco comandos simples: hostname, ls, findmnt, docker ps y dig. Debe decir «dónde lo corro, para qué sirve, qué salida espero, qué no demuestra».

**Segunda vuelta:** agrega uno por criterio: docker compose config --quiet, docker inspect -f de Web1/DB, curl con --resolve, haproxy -c, iptables -S y systemctl cat.

**Tercera vuelta:** el integrante que hace de profesor pregunta por una carpeta específica o por un fallo, y quien responde elige el comando correcto sin copiar uno largo de memoria. Si necesita el formato extenso, lo lee y explica opción por opción.

**Los ejemplos largos existen para obtener evidencias concretas con poco ruido**, pero no hay que memorizar todas sus letras. Hay que saber reconstruirlos a partir de comandos sencillos y entender las opciones.

**Límites firmes:** jamás mostrar wp-config.php ni claves/contraseñas; no cambiar firewall/NFS/BIND, reiniciar servicios, detener backends ni borrar datos solo por «probar» algo. La Entrega 3 está cerrada en lo técnico; esto es solamente material de estudio.
