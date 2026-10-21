# Matriz de autoevaluación — Entrega 3 (Nodo Sur, Grupo 7)

**Fecha de revisión:** 21/10/2026. **Base:** rúbrica proporcionada por el equipo, implementación y evidencia versionada en `e3/cierre-tecnico`. **No es una nota otorgada por el docente.** La rúbrica exige **verificación en implementación, no solo capturas**, con niveles 100, 80, 60, 30 y 0.

Esta matriz no reemplaza la demostración en vivo. La implementación usa cinco VMs: VM268 BIND9/NFS; VM263 WordPress web1; VM310 WordPress web2; VM279 MariaDB; VM308 HAProxy/HTTPS.

| Criterio literal de la rúbrica | Peso | Evaluación provisional (no oficial) | Evidencia que sí existe | Brecha que importa para el nivel 100 |
|---|---:|---|---|---|
| Aplicación multicontenedor reproducible | 15 | 60–80 | Compose por servicio y host (web1, web2, MariaDB, HAProxy), `docker compose config --quiet` en hosts, imagen declarada, rutas documentadas; cambios de Apache versionados | **Huellas Compose verificadas iguales** entre Fedora y VM263/VM310 (véase evidencia), pero no se ha reconstruido un entorno completo desde cero. NFS, secretos, TLS, BIND9, firewall y systemd aún requieren provisión y prueba; checkouts locales necesitan reconciliación |
| Dos backends funcionales | 15 | 80–100 | [Actualización core web2 a 7.1.3](../evidencias/e3/wordpress713-aplicacion-core-web2-20261021.txt); [lint PHP](../evidencias/e3/wordpress713-precheck-php-web2-20261021.txt); [recuperación web2: HTTP 200 en portada, tienda y NFS](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt); WooCommerce 11.1.0 y hashes plugins/temas coincidentes antes del cambio | **Desfase nominal 7.1.3/7.1.2 ya corregido:** ambos core declaran 7.1.3 y esquema 61833. Resta comprobar hashes de los árboles reales postactualización y posibles divergencias de configuración; no asumir equivalencia integral sin prueba |
| HAProxy, TLS y health checks | 20 | 80–100 | [Redirección HTTPS/config](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt), [TLS](../evidencias/e3/https-haproxy.txt), [DOWN por falla de conexión y 8/8 de web1](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt), [UP Layer7 HTTP 200 y balanceo 4/4](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt) | **Salud y reinclusión comprobadas** con checks `HEAD /`, `inter 3s fall 3 rise 2`; esto no demuestra salud integral de DB/NFS/checkout ni ausencia de errores en los segundos iniciales de la falla. TLS es autofirmado |
| Persistencia y coherencia del estado | 15 | 80 | Misma MariaDB y volumen histórico; [SHA-256 del upload](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) en NFS y ambos backends; [carrito compartido](../evidencias/e3/carrito-coherencia-postmigracion.txt) | No está probado checkout concurrente, persistencia de todas las sesiones, sincronía de plugins/configs ni RPO/RTO de datos. No alterar la BD ni carritos sin autorización |
| Segmentación, firewall y secretos | 15 | 80 | [Matriz de flujos](MATRIZ-FLUJOS-E3.md); [DOCKER-USER activo en ambas webs](../evidencias/e3/firewall-docker-user-web1-web2-20261021.txt), secretos externos a repo; [bloqueo Apache activo en ambos](../evidencias/e3/apache-uploads-web1-web2-final-20261021.txt) | Completar evidencia no destructiva de política SSH/DB/DNS y explicar qué capa bloquea el tráfico; escáner de secretos es heurístico, no una certificación |
| Prueba de falla y recuperación | 15 | 80–100 | [Parada controlada web2 y log HAProxy DOWN, 8/8 HTTP 200 vía web1](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt); [web2 7.1.3, reinicio y log UP, 8/8 HTTP 200 distribuidos 4/4](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt); [respaldo HTML](../evidencias/e3/respaldo-html-web2-pre-upgrade-20261021.txt) y [SQL reciente](../evidencias/e3/respaldo-mariadb-pre-cambio-web2-20261021.txt) | **DOWN y UP ya demostrados** con síntomas y validación posterior. No se cuantificaron errores de solicitudes durante detección ni se midieron formalmente RTO/RPO; no hubo ensayo de restauración del respaldo |
| Análisis de disponibilidad y documentación | 5 | 100 defendible | [Arquitectura](../ARQUITECTURA.md), [decisiones](decisiones-arquitectura.md), [riesgos](ENTREGA3.md): distinguen balanceo/tolerancia de falla y HA completa; identifican SPOF HAProxy, DB, DNS y NFS | Evitar llamar “alta disponibilidad integral” al sistema o inventar RTO/RPO; argumentar cómo evolucionaría a redundancia adicional |

## Orden razonado de cierre

**Prioridad 1 — Reproducibilidad y coherencia con Git:** la [guía de reconstrucción](DESPLIEGUE-REPRODUCIBLE-E3.md), el [preflight por rol](../scripts/preflight-e3.sh) y la [huella semántica de Compose](../scripts/compose-fingerprint-e3.sh) documentan requisitos y permiten verificar sin escrituras. **Pendiente verificarlos en los hosts reales**, revisar el PR #2 y reconciliar los checkouts de VM263/VM310 sin reemplazar sus configuraciones operativas. Esto NO sustituye una restauración integral desde cero.

**Prioridad 2 — Preparar evidencia de la demo:** seguir el [guion de 12–15 minutos](PLAN-DEMOSTRACION-E3.md): DNS, HTTP 301, HTTPS, cabecera `X-NodoSur-Backend`, ambos web `200`, archivo NFS, DB y reglas. Planificar fallo/reincorporación **solo cuando esté autorizada** y conservar evidencia `DOWN`/`UP` sin tocar DB/volúmenes.

**Prioridad 3 — Defensa oral:** explicar función de cada VM y de cada flujo, diferencias entre Docker Compose por host y orquestación, dependencia de servicios compartidos, limitación del `HEAD /` y certificado autofirmado. Mostrar resultados reales, no atribuir garantías de seguridad/HA que no fueron ensayadas.

## Escenario numérico únicamente orientativo

Si el docente asignara 60 a reproducibilidad, 80 a los cinco criterios centrales restantes y 100 a disponibilidad/documentación, el ponderado sería:

`15×0.60 + 15×0.80 + 20×0.80 + 15×0.80 + 15×0.80 + 15×0.80 + 5×1.00 = 78/100`.

Es un **escenario de referencia**, no la nota asegurada: la inspección en vivo puede acreditar niveles mayores o evidenciar fallos actualmente no detectados. Los rangos provisionales de la tabla son juicios técnicos, no selecciones oficiales de la columna H.
