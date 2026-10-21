# Nodo Sur — Grupo 7

**Taller de Administración de Sistemas (EIN-090B) · USM Sede Concepción · Segundo semestre 2026**

Proyecto de infraestructura para una plataforma WordPress/WooCommerce con dos servidores web, balanceo de carga y estado compartido. Esta es la implementación correspondiente a la **Entrega 3: publicación resiliente, contenedores y seguridad**.

**Estado de las comprobaciones: 21 de octubre de 2026.** El sistema está desplegado en el laboratorio iLab y se accede desde redes autorizadas. La mayoría de los cambios propuestos por Codex en la [auditoría separada](https://github.com/camilodrn/nodosur-tas-grupo7/pull/1) **no están desplegados**. Excepción comprobada: la protección Apache de `uploads` ya está activa en **web1 (VM263) y web2 (VM310)**; portada, tienda e imagen compartida HTTP 200 en ambos, ruta PHP inexistente HTTP 403 en ambos y HTTPS repartido 3/3 ([evidencia final](evidencias/e3/apache-uploads-web1-web2-final-20261021.txt)).

## Arquitectura implementada

`Cliente → DNS (VM268) → nombre del proxy (VM308) → WordPress web1 (VM263) / web2 (VM310) → MariaDB (VM279)`

El DNS resuelve el nombre; **no es un intermediario del tráfico HTTP**. Ambos WordPress usan una base de datos común y montan el directorio `uploads` desde NFS en VM268.

| VM | Rol | IP de acceso/administración | IP interna |
|---|---|---|---|
| 268 | BIND9, NFS y copia de respaldos | `10.33.195.205` | `10.33.199.59` |
| 263 | WordPress/WooCommerce web1, Docker | `10.33.195.202` | `10.33.199.58` |
| 310 | WordPress/WooCommerce web2, Docker | `10.33.195.208` | `10.33.199.62` |
| 279 | MariaDB 10.11, Docker | `10.33.195.226` | `10.33.199.60` |
| 308 | HAProxy 3.2, Docker y terminación HTTPS | `10.33.195.194` | `10.33.199.61` |

- **DNS:** `nodosur07.tas` y `www.nodosur07.tas` apuntan al proxy `10.33.195.194`.
- **Proxy:** HTTP 80 redirige a HTTPS 443; distribuye tráfico `roundrobin` a web1 `10.33.199.58:18081` y web2 `10.33.199.62:18080`. Usa health checks HTTP.
- **WordPress:** ambos contenedores declaran `wordpress:7.1.2-php8.3-apache`; el core, plugins y configuración local requieren coherencia entre nodos.
- **Datos:** MariaDB compartida en `10.33.199.60:3306`. Su volumen productivo mantiene el nombre histórico **`nodosur-db-staging_db_stage_data`**: no renombrar ni borrar.
- **Uploads:** `/srv/nodosur/nfs/uploads` está montado en ambos servidores web con lectura/escritura. Los archivos son servidos por los dos backends.

Consulta [ARQUITECTURA.md](ARQUITECTURA.md) para el diagrama, protocolos y límites; e [INVENTARIO.md](INVENTARIO.md) para los identificadores efectivos de las VMs.

## Evidencias de Entrega 3

| Prueba | Resultado sustentado |
|---|---|
| [Balanceo](evidencias/e3/balanceo-roundrobin.txt) | 8 respuestas HTTP 200: 4 de web1 y 4 de web2 |
| [Falla de web2](evidencias/e3/failover-web2-detenido.txt) | 8 respuestas HTTP 200 atendidas por web1 durante la prueba |
| [Reincorporación de web2](evidencias/e3/recuperacion-web2.txt) | 8 respuestas HTTP 200, distribuidas 4/4 |
| [HTTPS](evidencias/e3/https-haproxy.txt), [HTTP 301 y config válida](evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt) | HTTPS operativo; redirección a `https://nodosur07.tas/`; `haproxy -c` válido |
| [Certificado público](evidencias/e3/certificado-publico-y-repo-local-20261021.txt) | SAN para apex y `www`; certificado **autofirmado**, sin confianza automática de terceros |
| [Carrito WooCommerce](evidencias/e3/carrito-coherencia-postmigracion.txt) | Producto de prueba añadido en web1, consultado y retirado en web2 |
| [Persistencia de archivo](evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) | SHA-256 idéntico en NFS, HTTP web1 y HTTP web2 |
| [Firewall web1/web2](evidencias/e3/firewall-docker-user-web1-web2-20261021.txt) y [conectividad](evidencias/e3/acceso-proxy-backends-20261020.txt) | Reglas `DOCKER-USER` activas para puertos internos; proxy autorizado conecta, origen DB agotó tiempo |
| [Compose en las cuatro VMs](evidencias/e3/compose-productivo-db-proxy-20261021.txt), [web1/web2 y PHP](evidencias/e3/compose-productivo-web1-web2-y-php-20261021.txt) | Compose válido en los cuatro hosts Docker; contenedores en ejecución |
| [Validación de Codex en Fedora](evidencias/e3/validacion-local-fedora-20261021.txt) | 25/25 pruebas locales pasaron; barrido heurístico no detectó candidatos a secretos. **Corresponde al árbol local de auditoría, no a la rama estable ni a las VMs** |

Las evidencias se presentan con su alcance real: las capturas históricas no incluyen por sí solas los logs `DOWN/UP` del proxy ni una medición formal de RTO.

## Organización del repositorio

- `compose/`: Compose por rol y host. **No son un único Compose que despliegue cinco VMs automáticamente.**
- `configs/`: configuraciones saneadas y ejemplos; algunos corresponden a E2 y se identifican mediante la documentación.
- `scripts/`: validadores de DNS, web, MariaDB E3, preflight de estado por host y huella semántica de Compose, además de revisión heurística de secretos.
- [`pruebas/`](pruebas/README.md): índice de procedimientos, con la prueba de carrito protegida por autorización explícita y la separación E2/E3.
- `evidencias/e3/`: resultados verificables de pruebas.
- [Estado y pruebas E3](docs/ENTREGA3.md), [matriz de flujos](docs/MATRIZ-FLUJOS-E3.md), [autoevaluación de rúbrica](docs/RUBRICA-E3.md) y [decisiones](docs/decisiones-arquitectura.md).
- [Guía de reconstrucción y prerequisitos](docs/DESPLIEGUE-REPRODUCIBLE-E3.md) y [plan de demostración de 12–15 minutos](docs/PLAN-DEMOSTRACION-E3.md).
- [Revisión selectiva de mejoras de Codex](docs/REVISION-CODEX-E3.md): qué se incorporó, qué requiere pruebas y qué no se debe desplegar todavía.
- [Historial de Entrega 2](docs/historia/CHECKLIST_ENTREGA2.md): checklist original conservado fuera de la raíz, para no confundir E2 con E3.

**Reproducibilidad:** el mismo Compose debe describir lo que realmente está instalado. Las [huellas semánticas de web1 y web2](evidencias/e3/huellas-compose-web1-web2-verificadas-20261021.txt) coincidieron entre Fedora y las VMs. Para comprobarlo sin alterar los servicios, ejecutar [`scripts/compose-fingerprint-e3.sh`](scripts/compose-fingerprint-e3.sh) en el clon Fedora y en la VM correspondiente, y comparar huellas. Para validar estado/rutas/volumen mediante consultas de solo lectura está [`scripts/preflight-e3.sh`](scripts/preflight-e3.sh). Ver instrucciones y límites en la [guía](docs/DESPLIEGUE-REPRODUCIBLE-E3.md).

Las credenciales, certificados con claves privadas y `wp-config.php` reales permanecen **fuera de Git**. La reproducción de un host requiere también su configuración externa, los montajes NFS y sus datos; `docker compose config --quiet` verifica la definición, **no reconstruye por sí solo toda la infraestructura**.

## Verificaciones sin modificar las VMs

Desde Fedora, **conectado a la VPN y con resolución DNS correcta**, los scripts de esta rama pueden consultar web y DNS. A diferencia de los scripts antiguos, devuelven código de error cuando una prueba falla:

```bash
bash scripts/validate-dns.sh
NODOSUR_CA_CERT=/ruta/al/certificado-publico.crt bash scripts/validate-web.sh
python3 scripts/audit-secrets.py
```

Para un diagnóstico **sin comprobar confianza TLS**, se puede usar `NODOSUR_INSECURE=1 bash scripts/validate-web.sh`. Este modo no demuestra la identidad del servidor. No copiar claves privadas, contraseñas ni el PEM combinado de HAProxy a Fedora: usar únicamente el certificado público distribuido por un canal confiable.

Los validadores DNS y web son lecturas. En **VM279** (no en Fedora), el nuevo `bash scripts/validate-db-local.sh` revisa solo la estructura Compose, el estado, health check y nombre del volumen MariaDB mediante `sudo docker inspect`; ejecutar únicamente cuando el código actualizado esté disponible en esa VM. La prueba de carrito es **diferente**: escribe temporalmente, exige `--permitir-escritura --producto ID` y se reserva para una ventana de pruebas. La prueba de failover que afecta web2 se realizará en el ensayo final.

## Límites de disponibilidad

Se ha demostrado tolerancia a la caída **de un backend web** mientras el otro y las dependencias compartidas siguen disponibles. **No existe alta disponibilidad integral**: HAProxy, MariaDB, DNS y NFS son instancias únicas; VM268 concentra varios servicios importantes.

Las imágenes, sesiones autenticadas y operaciones de compra concurrentes no se consideran exhaustivamente validadas por la prueba de un archivo o de un carrito. No se declara un RTO/RPO medido ni una restauración integrada de WordPress y MariaDB.

## Seguridad y operación

Los accesos de administración son para cuentas autorizadas desde VPN/laboratorio. El certificado HTTPS es autofirmado y requiere confianza explícita para validar la identidad del servidor.

**No ejecutar a ciegas** `docker compose down -v`, `docker volume prune`, cambios de firewall o migraciones de rutas systemd en esta infraestructura: pueden afectar datos o interrumpir la defensa. Las mejoras de Codex continúan aisladas en su PR de auditoría y requieren una adopción planificada.
