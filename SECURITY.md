# Seguridad de Nodo Sur — Entrega 3

Esta guía distingue medidas **observadas en las VMs** de propuestas de Codex que aún no se instalan. El laboratorio funciona con dos WordPress, HAProxy, MariaDB y NFS en cinco VMs.

## Secretos y materiales que no van a GitHub

No versionar contraseñas Linux/WordPress/MariaDB, hashes sensibles, salts de WordPress, `wp-config.php` real, certificados combinados con clave privada, claves SSH/VPN/iLab, tokens, cookies de sesión, backups ni volcados SQL con datos reales.

Los ejemplos de configuración no deben contener valores privados. Los servicios obtienen archivos secretos fuera de Git en rutas administradas, como `/etc/nodosur/secrets/` y `/etc/nodosur/tls/`. **No imprimir el contenido de esos archivos** para presentar evidencia. El PEM usado por HAProxy puede incluir certificado y clave privada: para demostrar SAN, vigencia y fingerprint se consulta solamente el certificado público del servidor.

`.gitignore` reduce la probabilidad de subir archivos privados, pero no elimina secretos ya rastreados ni reescribe el historial. En Fedora se ejecutó `python3 scripts/audit-secrets.py` sobre el árbol local y blobs accesibles de la auditoría sin candidatos detectados. Es una **búsqueda heurística**, no garantía absoluta ni auditoría de secretos residentes en las VMs.

## Restricción de acceso y exposición

| Control | Estado comprobado y límite |
|---|---|
| HTTPS | VM308 devuelve HTTP 301 hacia `https://nodosur07.tas/`; certificado autofirmado con SAN apex/www, sin confianza pública automática |
| Balanceador | HAProxy publica puertos 80/443, conecta a web1/web2 por puertos TCP internos y realiza health checks HTTP |
| Backends | VM263 y VM310 tienen `nodosur-docker-firewall.service` activo y habilitado; reglas `DOCKER-USER` descartan conexiones TCP desde orígenes distintos del proxy `10.33.199.61` a puertos 18081/18080 |
| MariaDB | El proxy no logró establecer TCP hacia 3306 en la prueba histórica; web1/web2 sí. Evitar interpretar un timeout como prueba única de la cadena que bloqueó |
| NFS | Ambas webs acceden a uploads del servidor VM268. La prueba SHA-256 verificó lecturas idénticas; no demuestra prevención de ejecución PHP ni aislamiento de cada archivo subido |

Ver [matriz de flujos E3](docs/MATRIZ-FLUJOS-E3.md), [firewall en web1/web2](evidencias/e3/firewall-docker-user-web1-web2-20261021.txt) y [datos públicos del certificado](evidencias/e3/certificado-publico-y-repo-local-20261021.txt).

**Comprobación adicional (21/10/2026):** Apache en ambos WordPress respondió `Syntax OK` con advertencia no crítica `AH00558` de `ServerName`. El archivo de configuración de endurecimiento propuesto para uploads no está instalado y no hay `.htaccess` dentro de uploads en web1. Esto **no permite afirmar por sí solo que PHP se ejecute en uploads**; falta comprobar reglas globales/heredadas antes de considerar el cambio. En web2 se confirmó sin revelar valores que `/run/secrets/db_password` está presente, no vacío, y que `wp-config.php` contiene una referencia a ese archivo. No se concluye necesidad de migrar credenciales. [Evidencia](evidencias/e3/apache-secretos-y-validadores-20261021.txt).

## Medidas propuestas, pendientes de instalación

Codex propone bloquear interpretación de PHP/CGI desde `wp-content/uploads`, mejorar saneamiento de encabezados en HAProxy, usar lectura explícita de archivo secreto para MariaDB en web2, reforzar prechequeo de NFS y reorganizar políticas de firewall/systemd. **No se consideran medidas productivas solo por existir en el PR de auditoría.** Requieren validar sintaxis, configuración efectiva, comportamiento y reversión antes de adoptarlas.

En particular, el cambio de firewall no debe reemplazar una regla que ya funciona sin examinar las cadenas existentes y la ruta administrativa de recuperación. Los nombres de volúmenes Docker de MariaDB no se deben alterar a ciegas: el productivo es `nodosur-db-staging_db_stage_data`, pese a su nombre histórico.

## Publicación de evidencias

Preferir salidas saneadas: estado del contenedor, imagen, volumen **por nombre**, respuesta HTTP, fingerprint público y contadores de firewall. No publicar `docker inspect` completo, contenido de `wp-config.php`, variables de entorno completas, `Set-Cookie`, `Cart-Token` ni datos personales de usuarios o pedidos.

Ante una filtración real, coordinar retiro del material y **rotación** del secreto correspondiente. Eliminarlo de un commit posterior no garantiza que haya desaparecido del historial o de clones existentes.
