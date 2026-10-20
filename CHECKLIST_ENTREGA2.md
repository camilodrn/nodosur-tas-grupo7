# Checklist Entrega 2

> Registro histórico de E2. El cierre E3 y sus pendientes están en [docs/ENTREGA3.md](docs/ENTREGA3.md); no extrapolar estas validaciones de tres VMs a cinco.

Estado técnico consolidado del repositorio. No reemplaza la rúbrica oficial.

| Área | Estado | Evidencia principal |
|---|---|---|
| Inventario y arquitectura | Validado | `INVENTARIO.md`, `ARQUITECTURA.md` |
| DNS autoritativo | Validado | `configs/dns/`, `pruebas/dns.md` |
| Web HTTP/HTTPS | Validado | `configs/apache/`, `pruebas/web-https.md` |
| PHP-FPM | Validado | `pruebas/web-https.md`, logs de servicio |
| WordPress/WooCommerce | Validado | sitio, tienda y pedido real de prueba |
| MariaDB separada | Validado | `configs/mariadb/`, `pruebas/base-datos.md` |
| Firewall UFW | Validado | `configs/firewall/README.md` |
| SSH nominativo/hardening | Validado | `configs/ssh/`, `pruebas/ssh-firewall.md` |
| Sudo limitado por rol | **Validado** | `configs/sudo/`, `pruebas/ssh-firewall.md` |
| Cuenta temporal de revisión docente | **Validado** | `tas_revision` con sudo completo en las 3 VMs; credenciales fuera del repo |
| Almacenamiento persistente | Validado | `pruebas/almacenamiento.md` |
| Logs/observabilidad | Validado | `pruebas/logs-observabilidad.md` |
| VMs actualizadas | Validado | `pruebas/actualizaciones.md` |
| Bitácora de incidentes | Documentada | `BITACORA.md` |
| Manejo de secretos | **Validado para publicación** | `SECURITY.md`, `.gitignore`, barrido del árbol actual |
| Flujo empresarial WooCommerce | **Validado** | pedido `#71` correlacionado cliente → admin → MariaDB, `pruebas/flujo-woocommerce.md` |
| Contribuciones por integrante | **Documentadas** | `CONTRIBUCIONES.md`; sin inventar reparto retrospectivo |
| Coherencia documental pre-publicación | **Validada** | README, arquitectura, decisiones, scripts y pruebas alineados con el estado final |
| Defensa individual | **Pendiente de preparación** | documentación del repositorio |

## Estado de privilegios administrativos

Las cuentas nominativas del equipo (`cduran`, `nmatamala`, `jsaez`, `jdiaz`) ya no pertenecen al grupo `sudo`. Todas comparten el grupo operativo `nodosur-ops` y disponen únicamente de comandos sudo acordes al rol del servidor:

- `.58 WEB`: Apache, PHP-FPM y consulta de UFW.
- `.59 DNS`: BIND/rndc, validación de zona y consulta de UFW.
- `.60 DB`: gestión del servicio MariaDB, comprobación mediante script fijo y consulta de UFW.

Los integrantes pueden leer el journal de servicios mediante `systemd-journal`. Las pruebas negativas `sudo /bin/bash` fueron rechazadas en las tres VMs; en `.60` también se confirmó que `sudo /usr/bin/mariadb` está bloqueado para las cuentas operativas.

Cada VM conserva una cuenta bootstrap/recovery con sudo completo:

- `.58`: `tas_07`
- `.59`: `nodosur-g7`
- `.60`: `svr-db-nodosur07`

La cuenta `tas_revision` es temporal para revisión docente y posee sudo completo en las tres VMs. Su contraseña se mantiene fuera del repositorio y debe revocarse al finalizar la evaluación.

## Contribuciones

Las contribuciones se registraron de forma retrospectiva a partir de lo efectivamente realizado. Debido a que el repositorio se consolidó al final del hito, el historial de Git no representa por sí solo toda la distribución del trabajo. `CONTRIBUCIONES.md` distingue explícitamente entre implementación final, documentación, pruebas y aportes exploratorios no incorporados.

## Barrido pre-publicación

Se revisó el árbol actual del repositorio antes de exponerlo públicamente. El estado validado no contiene archivos `.env`, claves privadas `.key/.pem`, dumps `.sql/.dump`, respaldos comprimidos, `wp-config.php` real ni contraseñas de cuentas Linux, WordPress o MariaDB. El ejemplo de WordPress utiliza un placeholder para `DB_PASSWORD` y las credenciales de `tas_revision` permanecen fuera de GitHub.

También se corrigieron referencias documentales anteriores que ya no coincidían con el estado final, especialmente la política de sudo y la validación administrativa de MariaDB.

## Pendientes reales de cierre

1. **Defensa:** preparar explicación individual de arquitectura, decisiones, diagnóstico y validaciones.
2. **SPOF:** la arquitectura actual mantiene un único DNS, web y DB por rol. No declarar HAProxy/NFS/segundo backend como implementados.

El repositorio se considera técnicamente listo para publicación y revisión docente.
