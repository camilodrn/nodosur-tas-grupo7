# Seguridad de Nodo Sur — Entrega 3

Esta guía distingue las medidas **observadas en las VMs** de las propuestas de Codex que siguen pendientes. La protección Apache de `uploads` está instalada en **ambos servidores web (VM263 y VM310)** durante E3, con prueba de disponibilidad e imágenes conservadas. El laboratorio funciona con dos WordPress, HAProxy, MariaDB y NFS en cinco VMs.

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

**Comprobación adicional (21/10/2026):** Apache en ambos WordPress respondió `Syntax OK` con advertencia no crítica `AH00558` de `ServerName`. Al momento de esa comprobación histórica aún no estaba instalada la protección de uploads; **posteriormente se instaló en web1 y web2**. Esto **no permite afirmar por sí solo que PHP se ejecute en uploads**; falta comprobar reglas globales/heredadas antes de considerar el cambio. En web2 se confirmó sin revelar valores que `/run/secrets/db_password` está presente, no vacío, y que `wp-config.php` contiene una referencia a ese archivo. No se concluye necesidad de migrar credenciales. [Evidencia](evidencias/e3/apache-secretos-y-validadores-20261021.txt).

**Barrido final en NFS (VM268):** la búsqueda privilegiada de archivos con extensiones `.php*`, `.phtml` y `.phar` terminó sin errores y contó **0 coincidencias**. La comprobación equivalente en el `.htaccess` principal de web2 tampoco encontró las directivas de denegación consultadas. No existe evidencia de PHP malicioso presente, pero se recomienda impedir su ejecución futura en `uploads`. [Evidencia](evidencias/e3/nfs-php-y-htaccess-web2-20261021.txt).

Se incorporó al repositorio el archivo [`configs/apache/nodosur-uploads.conf`](configs/apache/nodosur-uploads.conf), que deniega PHP/PHTML/PHAR bajo `uploads` y deshabilita CGI/listado de directorio. **Está montado y activo en web1 y web2** mediante bind de solo lectura, con `apache2ctl -t` correcto; ambas portadas, tiendas e imagen real de NFS respondieron HTTP 200, y la ruta PHP inexistente bajo uploads respondió HTTP 403 ([evidencia final](evidencias/e3/apache-uploads-web1-web2-final-20261021.txt)). Una prueba **aislada** comprobó 200/403 para archivos `.txt`/`.php` realmente existentes fuera de producción. No se prueba aquí la resistencia frente a todos los vectores de ejecución.

## Medidas propuestas, pendientes de instalación

La medida de **bloquear interpretación de PHP/CGI en `wp-content/uploads` ya se probó e instaló en web1 y web2** (ver evidencia final anterior). Las propuestas restantes de Codex incluyen mejorar saneamiento de encabezados en HAProxy, reconsiderar la referencia al archivo de secreto de MariaDB en web2, reforzar el prechequeo de NFS y reorganizar políticas de firewall/systemd. **No se consideran productivas solo por existir en el PR de auditoría.** Requieren validar configuración efectiva, comportamiento y reversión antes de adoptarlas.

En particular, el cambio de firewall no debe reemplazar una regla que ya funciona sin examinar las cadenas existentes y la ruta administrativa de recuperación. Los nombres de volúmenes Docker de MariaDB no se deben alterar a ciegas: el productivo es `nodosur-db-staging_db_stage_data`, pese a su nombre histórico.

## Publicación de evidencias

Preferir salidas saneadas: estado del contenedor, imagen, volumen **por nombre**, respuesta HTTP, fingerprint público y contadores de firewall. No publicar `docker inspect` completo, contenido de `wp-config.php`, variables de entorno completas, `Set-Cookie`, `Cart-Token` ni datos personales de usuarios o pedidos.

Ante una filtración real, coordinar retiro del material y **rotación** del secreto correspondiente. Eliminarlo de un commit posterior no garantiza que haya desaparecido del historial o de clones existentes.
