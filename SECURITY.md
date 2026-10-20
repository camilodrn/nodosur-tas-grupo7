# Seguridad y custodia de secretos

No subir contraseñas de Linux/WordPress/MariaDB, salts, `wp-config.php` real, claves TLS/SSH, credenciales VPN/iLab/Proxmox, tokens/cookies ni dumps/respaldos. Las configuraciones deben usar referencias a archivos externos o placeholders inequívocos.

`.gitignore` reduce inclusiones accidentales; no elimina secretos ya rastreados ni limpia el historial. Ejecutar `python3 scripts/audit-secrets.py` antes de publicar. El scanner inspecciona árbol (incluidos archivos ignorados salvo `.git` físico/cache Python), permisos world-writable y blobs alcanzables de todas las refs locales; muestra solo regla, ubicación y conteos, sin valores. Es heurístico y no sustituye revisión manual, escaneo de binarios/archivos comprimidos ni auditoría del servidor. No examina objetos inalcanzables, otras máquinas o refs remotas no presentes.

En esta auditoría no se detectaron candidatos confirmados a secretos en el alcance examinado. Consultar [evidencia fechada](evidencias/e3/auditoria-local.txt) para conteos y revisiones cubiertas; no interpretarlo como garantía de ausencia absoluta.

## Permisos de despliegue

- `/opt/nodosur`, unidades, wrappers y bibliotecas: root:root, padres sin escritura operativa; ejecutables 0755 y configuraciones públicas 0644.
- Secretos root MariaDB y respaldos: directorios 0700, archivos 0600. PEM TLS según usuario lector efectivo, sin lectura global.
- Secreto web2: root con grupo numérico lector de PHP y 0640 si ese es el modelo elegido; comprobar identidad real y lectura dentro del contenedor. Los secrets Compose basados en archivo no garantizan aplicar metadatos de permisos diferentes a los del host.
- `wp-config.php`: lectura para PHP, escritura solo administrativa. Salts comunes entre backends; no regenerar sin plan de invalidación de sesiones.
- Datos NFS: UID/GID coherentes, permisos mínimos, `root_squash`; sin `777`. El bloqueo Apache propuesto evita interpretar scripts subidos; `noexec` del mount por sí solo no lo hace.
- Cuentas nominativas sin sudo genérico ni grupo Docker. El acceso al daemon permite control equivalente a root. La política histórica E2 no prueba los permisos de las cinco VMs E3.

## Evidencias e incidentes

No publicar salida completa de `docker inspect`, entornos de procesos, `wp-config`, certificados combinados con clave ni cabeceras Set-Cookie/Cart-Token. Guardar los originales sensibles en custodia privada y publicar solo extractos mínimos saneados.

Si aparece un secreto real: retirarlo del material compartido y rotarlo con el custodio autorizado; borrar el archivo de la última versión no lo revoca. Una reescritura de historial requiere coordinación y no forma parte de esta auditoría. Las cuentas temporales docentes deben revocarse al finalizar evaluación; comprobar su alcance efectivo en las cinco VMs sin exponer las credenciales.
