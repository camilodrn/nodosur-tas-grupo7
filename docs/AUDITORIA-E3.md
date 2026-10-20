# Informe de auditoría técnica E3 — 20-10-2026

**Dictamen:** existe evidencia funcional de una arquitectura distribuida de cinco VMs y continuidad ante fallo de un backend. El repositorio presentaba errores de reproducción y documentación que se corrigieron localmente. La entrega aún requiere validación de adopción, evidencia de respaldo remoto/configuración NFS y contraste con la rúbrica oficial. No se certifica alta disponibilidad integral ni recuperación completa.

## Alcance y método

Se verificó rama `audit/e3-codex`, inicialmente limpia, con HEAD y `e3/integracion` en `279466d`; reflog indica creación desde HEAD y Git confirma ascendencia. Se leyó todo el árbol versionado inicial (Compose, scripts, unidades/drop-ins, configuraciones, pruebas, evidencias y documentos) y la historia de E2/E3. Se conservaron los originales de evidencia y copias exactas de documentos E2.

Se revisaron despliegue, red, privilegios, persistencia, estado compartido, respaldos y recuperación. Las comprobaciones locales no iniciaron contenedores, no consultaron servicios de las VMs ni ejecutaron SSH, migraciones, escrituras de carrito, reinicios, cambios de firewall o eliminación de datos. Los tests usan fixtures ficticios en directorios temporales y dobles de Docker/iptables. Los procedimientos de laboratorio son instrucciones pendientes, no resultados.

**Clasificación:** P0 = compromiso/pérdida crítica confirmada que exige detener la entrega; P1 = riesgo significativo de seguridad, disponibilidad o reproducción que debe corregirse/validarse antes de cierre; P2 = mejora o falta de evidencia/documentación que limita la defensa. “Corregido localmente” nunca significa “desplegado”.

## Hallazgos P0

**No se identificaron P0 confirmados en el alcance disponible.** Esto no descarta problemas en las VMs, imágenes, secretos externos o infraestructura no accesible. No se encontraron candidatos confirmados a credenciales publicadas mediante el barrido descrito abajo.

## Hallazgos P1

| ID | Hallazgo verificable / impacto | Corrección local | Pendiente en infraestructura |
|---|---|---|---|
| P1-01 | Staging DB y producción compartían proyecto, contenedor y volumen; proxy de pruebas y producción también compartían identidad. Operar staging podía reconfigurar producción. | Proyectos/contenedores de laboratorio separados; volumen productivo externo explícito y sin renombre de datos. | **Volumen productivo confirmado en VM279** como `nodosur-db-staging_db_stage_data`. Resta comprobar staging aislado y su secreto antes de usarlo. |
| P1-02 | El repositorio incluía unidades de firewall por backend, pero las VMs utilizan efectivamente un servicio **genérico** `nodosur-docker-firewall.service`: confirmado `loaded/active` en web1 y web2. Sus drop-ins dependen de él y existen reglas `DOCKER-USER` que limitan acceso al proxy `.61`. Por tanto, la afirmación inicial de que el servicio genérico era inexistente **no aplica a producción**. Sigue pendiente comprobar el comportamiento ante reinicio de Docker. | Codex propuso unidades específicas, nuevos drop-ins y `PartOf`. Son una **migración propuesta**, no un arreglo urgente de un firewall ausente. | No reemplazar las unidades actualmente activas antes de reconciliar la configuración instalada, comprobar reinicio y preparar `/opt/nodosur`. |
| P1-03 | systemd root ejecutaba Compose desde homes de usuarios, incluido `tas_revision`. La integridad depende de permisos no capturados y de una cuenta temporal. | Ruta uniforme `/opt/nodosur`, instalación root-owned documentada. | Verificar `namei -l` y ownership real antes de habilitar; no se confirmó explotación ni permisos del host remoto. |
| P1-04 | Firewall DB/proxy limitado a una interfaz; inserciones separadas dependían del orden de excepciones. `.59` conservaba acceso SQL heredado. | Cadena por rol y reemplazo transaccional, destino original DNAT por cualquier ingreso, prioridad explícita; DB solo web1/web2. | Validación kernel real, matriz completa y compatibilidad de acceso `.59`; no se ejecutó una prueba de bypass. |
| P1-05 | Reproducción WordPress incompleta: web2 montaba secreto sin `WORDPRESS_DB_PASSWORD_FILE` y el bind HTML podía crearse vacío; `mountpoint` por sí solo no comprueba origen NFS RW. | `_FILE`, binds sin creación automática y prechequeo NFS tipo/origen/RW. | **NFS real confirmado** en VM263/310: origen `10.33.199.59:/srv/nodosur/uploads`, NFSv4.1 RW; VM268 exporta RW con `root_squash` a `.58` y `.62`. Faltan prueba cruzada de escritura, configuración efectiva `wp-config.php`, permisos de secreto y salts comunes. |
| P1-06 | Los scripts versionados de respaldo carecían de lock robusto, escape del secreto y tolerancia a cambios legítimos de número de tablas; faltaban definiciones completas del timer en el repositorio. | Motor común con bloqueo, escape, validación y publicación checksum al final; unidad base/timer como propuesta. | **VM279 sí tiene instalados y programados** `nodosur-db-backup.timer` y `nodosur-backup-replicate.timer`. Contrastar sus unidades y scripts reales: no añadir timers duplicados ni sustituir un respaldo operativo sin prueba. |
| P1-07 | Las implementaciones de réplica y mantenimiento remoto no están versionadas y no hay recuperación integral documentada de uploads/configuración/grants. **El servicio de mantenimiento remoto sí existe y reporta ejecución exitosa en VM268**, con cinco dumps y manifiestos de checksum coincidentes por nombre con VM279. | Runbook con verificación SHA/GZIP, restauración aislada y requisitos de recuperación integral; evidencia de inventario versionada. | **Abierto:** capturar scripts/unidades reales saneados, política de retención e integridad actual, comprobar copia de uploads y ensayar restauración integral. |

## Hallazgos P2

| ID | Hallazgo / limitación | Tratamiento y pendiente |
|---|---|---|
| P2-01 | README/arquitectura/inventario/decisiones describían tres VMs y DNS ejemplo apuntaba a `.202`. | Corregido a cinco VMs y `.194`; E1/E2 preservadas. Verificar zona realmente servida. |
| P2-02 | Validadores web/DNS/SSH/DB podían enmascarar fallos o apuntaban a servicios E2; carrito dependía de JSON ausente en `/tmp`. | Retornos no cero/timeouts, DB E3 con helper fijo, validación TLS explícita, producto obtenido por API y bandera de escritura. |
| P2-03 | Documento decía diez solicitudes 5/5; archivos guardados tienen ocho 4/4 y HTTPS seis 3/3. Copia remota carece de salida versionada. | Separado “evidenciado” de “reportado”; conservar originales, capturar salida faltante. No se invalida lo reportado por el equipo. |
| P2-04 | Tags de imagen sin digest; MariaDB mutable; bind WordPress puede tener versión distinta del tag. | No se cambiaron versiones sin prueba. Capturar digests reales, versiones/plugins y verificar disponibilidad/vulnerabilidades antes de fijar. No hay dictamen CVE. |
| P2-05 | Confianza de encabezados y uploads ejecutables no estaban acotados en la configuración pública. | Proxy sustituye metadatos, TLS mínimo 1.2, fragmento WP con confianza por origen, denegación Apache de scripts en uploads. Validación nativa y adopción pendientes. No se demostró una explotación. |
| P2-06 | Unidades oneshot + `restart: no` no recuperan automáticamente todo proceso caído; `--wait` sin healthcheck no prueba disponibilidad web/proxy. | Limitación documentada; comprobar Docker/HAProxy, establecer supervisión/alerta si lo exige la rúbrica. No prometer autorecuperación total. |
| P2-07 | SPOF: proxy, DB, DNS y NFS; VM268 concentra DNS/archivos/backup. Red /29 sin IP libre. TLS interno y NFS fuerte no configurados. | Declaración explícita del alcance y capacidad. Redundancia, copia externa y cifrado interno requieren trabajo separado. |
| P2-08 | Privilegios/cuentas/actualizaciones documentados solo para tres VMs E2; no hay inventario SO/recursos de nuevas VMs. | Sudo E2 marcado histórico, ejemplo DB E3 limitado; verificar cinco VMs, custodia y revocación docente. |
| P2-09 | Rúbrica oficial ausente; sin RPO/RTO medidos ni evidencia central de alertas/retención. | Matriz provisional sin puntuaciones, procedimientos y criterios de cierre. Correspondencia académica pendiente. |
| P2-10 | `.git` del workspace es solo lectura; impide commits sobre la rama original. | Se conserva trabajo local y se prepara rama homónima en copia independiente con bundle/parches. Limitación del entorno, no del sistema productivo. |

## Contraste posterior con laboratorio (20-10-2026)

Estas observaciones proceden de salidas de terminal aportadas por el equipo **después** de la auditoría local de Codex. No se ejecutaron desde esta auditoría ni sustituyen una evidencia de consola versionada:

- VM279: `docker inspect nodosur-db-staging` confirma volumen `nodosur-db-staging_db_stage_data` en `/var/lib/mysql`; `nodosur-db-prod.service` activo desde `/home/tas_revision/nodosur-tas-grupo7`; dos timers de respaldo/réplica instalados y programados.
- VM308: `nodosur-proxy.service` activo desde `/home/nodosur-g7-proxy/nodosur-tas-grupo7`; HAProxy en Docker publica 80/443 en `.194`; reglas `DOCKER-USER` de origen VPN/laboratorio presentes.
- VM263 y VM310: montaje NFSv4.1 RW, mismo export de VM268; ambos servicios WordPress `active`, `nodosur-docker-firewall.service` `loaded/active`, dependencias en drop-ins y reglas `DOCKER-USER` restrictivas. Las unidades específicas propuestas no están instaladas, lo que **no constituye por sí solo una falla de los firewalls existentes**.
- VM268: export NFS RW a `.58` y `.62`, con `root_squash`; `/srv/nodosur` está en un volumen ext4. Sigue pendiente un ensayo controlado de escritura cruzada.
- Pruebas TCP posteriores ([salidas archivadas](../evidencias/e3/acceso-proxy-backends-20261020.txt)): desde VM308 el puerto web1 `18081` y web2 `18080` aceptó conexiones; desde VM279 ambos intentos agotaron el tiempo de espera. Esto concuerda con la política `DOCKER-USER` observada en las VMs web, pero el timeout por sí solo no demuestra que el firewall sea la causa exclusiva.
- En la rama auditada se corrigió el uso de `-g` a `-j` en la biblioteca del firewall y se añadió una regresión para reglas posteriores de `DOCKER-USER`; **la nueva prueba no se ha ejecutado ni el cambio adoptado en VMs**.
- Inventario de respaldo local VM279 y remoto VM268 ([evidencia textual](../evidencias/e3/respaldo-local-remoto-20261020.txt)): cinco identificadores SQL `.sql.gz` y sus `.sha256` aparecen en ambos destinos. En VM268 `nodosur-remote-backup-maintenance.service` registra `Result=success`, `ExecMainStatus=0` y salida el `2026-10-20 23:02:26 UTC`, con siguiente timer programado; en VM279 el estado `success/0` no incluye `ExecMainExitTimestamp`, por lo que no atribuye fecha de última ejecución. Aún no se ha probado el backup integral de WordPress.

## Pruebas locales realizadas

Salida completa saneada: [evidencias/e3/auditoria-local.txt](../evidencias/e3/auditoria-local.txt).

| Comprobación | Resultado y límite |
|---|---|
| Branch/base/árbol inicial | audit/e3-codex = e3/integracion = 279466d, sin cambios iniciales |
| Sintaxis Bash y Python | Correcta; no ejecuta los scripts productivos |
| Seis Docker Compose | `config --quiet` y JSON válidos con cliente Compose v5.5.1; no acredita imágenes, mounts externos ni salud |
| DNS | `named-checkzone` de ejemplo con serial 2026102001: OK; sin consulta a BIND real |
| Sudo | Cuatro ejemplos aceptados por `visudo -cf`; no instalados ni ejecutados como usuarios operativos |
| Regresión local | 25 pruebas aprobadas: fallos de dump/salud/lock, checksum/permisos, escape de secreto ficticio, cambio de esquema, corrupción/manifiesto, matriz/idempotencia de firewall simulado, dependencias, HTTP/DNS y rechazo de mounts incorrectos |
| Git whitespace / enlaces documentales | Diff sin errores; enlaces relativos locales verificados al cierre |
| Históricos | Copias E2 contrastadas con `0f4cfe2`; evidencias originales contrastadas con `279466d` |
| Secretos/permisos | Barrido heurístico del árbol y blobs de todas las refs locales; sin candidatos en la ejecución registrada; sin archivos world-writable detectados |

**No comprobado:** daemon Docker inaccesible por permisos del socket; HAProxy, PHP, Apache, `named-checkconf` y ShellCheck no disponibles. `systemd-analyze verify` terminó con error de sockets (`SO_PASSRIGHTS`/`SO_PASSCRED`, Operation not permitted), por lo que no se declara validación nativa de unidades. Se comprobó estáticamente que las dependencias `nodosur-*` referenciadas existan; eso no prueba arranque. No se intentó eludir permisos, instalar paquetes, iniciar servicios ni abrir conexiones a VMs.

El barrido de secretos no demuestra ausencia absoluta. No analiza exhaustivamente entropía, binarios/cifrados, contenido comprimido, objetos Git inalcanzables ni estado remoto. La inspección de permisos del repositorio no permite concluir permisos de `/etc`, `/srv`, homes o backups en las VMs. No se publicaron credenciales ni dumps reales.

## Reproducción y cierre

```bash
bash scripts/validate-repository.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit-secrets.py
git diff --check
```

En laboratorio, seguir [instalación](INSTALACION-E3.md), [operación](OPERACION-E3.md) y [recuperación](RECUPERACION-E3.md). Prioridad antes del 23 de octubre:

1. Confirmar material privado recuperable, volumen DB real y configuración remota de respaldo/NFS. Guardar evidencia saneada de último backup remoto e importación aislada.
2. Adoptar/revisar P1-01 a P1-06 en una ventana controlada; validar un backend por vez, reglas antes de publicar servicios, sin renombrar datos ni arrancar una DB vacía.
3. Capturar diez solicitudes, DOWN/UP, DNS, SAN y matriz de red completa con tiempos. Revalidar sesiones y NFS compartido tras las correcciones.
4. Comprobar cuentas/permisos/recursos de cinco VMs y rúbrica oficial. Preparar defensa individual sin extrapolar E2 ni atribuir evidencia que no existe.

## Entrega de cambios y commits

El intento de `git add` en el workspace falló: `Unable to create .../.git/index.lock: Read-only file system`. Por la política del entorno no es posible avanzar la referencia de la rama original. No se pidió modificar permisos ni se alteró el montaje.

Los commits se crearon en la copia Git independiente `/tmp/nodosur-e3-audit-review` en la rama `audit/e3-codex`, basada en `279466d`. Se entregan en `audit-artifacts/` (ignorado por Git) como bundle incremental, parches por commit, lista de hashes e instrucciones (`audit-artifacts/README.md`). Los dos primeros commits separan correcciones técnicas (`606d2e3`) de validadores y regresiones; el tercero consolida documentación y evidencia. La lista completa está en el manifiesto del paquete. Los cambios visibles del workspace corresponden al contenido revisado; la referencia original permanece en la base. No hubo push ni merge. Los hashes concretos están en `audit-artifacts/COMMITS.txt` y en la respuesta de cierre; no se atribuye a la rama original un commit que no contiene.
