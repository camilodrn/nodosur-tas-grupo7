# Checklist específico — Entrega 3 Nodo Sur (pauta del proyecto integrador 2026)

Fuente de requisitos: `Proyecto_Integrador_TAS_2026_Nodo_Sur(2).docx`, páginas 12–13 (documento compartido por el equipo en ChatGPT). **No se ha incorporado el DOCX al repositorio.** La tabla de ponderaciones 15/15/20/15/15/15/5 figura en el resumen previo del equipo, pero **no aparece en esas páginas del documento base**; no usarla para atribuir puntajes oficiales sin la rúbrica separada.

## Alcance obligatorio y estado según evidencias conocidas

| Pauta E3 | Evidencia observada | Qué falta para cerrar con rigor |
|---|---|---|
| CMS multicontenedor reproducible con Compose | `compose/proxy/compose.prod.yaml`, `compose/db-stage/compose.prod.yaml`, Compose web y documentación versionada; VMs y contenedores efectivos comprobados en auditoría | Verificar que lo versionado reproduce la instalación real (workdir de systemd hoy en home; propuesta `/opt/nodosur` NO instalada); ejemplo de variables sin secretos y script de validación ejecutado |
| Dos backends equivalentes, identificables | [8 solicitudes 4/4](../evidencias/e3/balanceo-roundrobin.txt), respuestas `X-NodoSur-Backend`; montajes NFSv4.1 RW observados en web1/web2 | [El mismo upload se sirvió idéntico desde web1/web2 y NFS por SHA-256](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt); pendiente equivalencia de versiones/plugins |
| HAProxy como entrada HTTP/HTTPS, redirección TLS, health checks | [HTTP 301 y Location HTTPS confirmados](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt); [6 peticiones HTTPS exitosas 3/3](../evidencias/e3/https-haproxy.txt); config `compose/proxy/haproxy.prod.cfg` con roundrobin, HEAD / y checks de servidor | Validación `haproxy -c` en VM308 confirmada con código 0 ([evidencia](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt)); faltan logs DOWN/UP y SAN/vigencia del certificado autofirmado (sin compartir clave privada) |
| Persistencia coherente de DB/archivos/imágenes/sesiones | [Carrito compartido postmigración](../evidencias/e3/carrito-coherencia-postmigracion.txt); NFS RW desde mismo export, volumen MariaDB productivo confirmado | Upload idéntico en web1/web2/NFS comprobado; carrito compartido histórico. Pendientes sesiones autenticadas/checkout si se exigen, y validación de escrituras nuevas |
| Firewall, NAT/forwarding y segmentación | [Proxy conecta con ambos web; DB no conecta](../evidencias/e3/acceso-proxy-backends-20261020.txt), y [firewall de DB](../evidencias/e3/firewall-db-tras-reinicio.txt); reglas `DOCKER-USER` activas en producción según terminales | [Matriz explícita de flujos](MATRIZ-FLUJOS-E3.md) y [reglas DOCKER-USER de web1/web2](../evidencias/e3/firewall-docker-user-web1-web2-20261021.txt) comprobadas; pendientes filtros efectivos del proxy/DB y algunos orígenes |
| Secretos fuera de imágenes y repositorio | Se usan bind mounts privados para TLS y contraseñas; barrido heurístico en auditoría | Confirmar mounts/config efectivos sin mostrar valores, reejecutar barrido de secretos antes de entrega |
| Logs proxy/backends para balanceo, falla y retorno | [Falla: 8 respuestas web1](../evidencias/e3/failover-web2-detenido.txt); [recuperación: 8 respuestas 4/4](../evidencias/e3/recuperacion-web2.txt) | Guardar líneas saneadas HAProxy DOWN/UP, comandos y marcas de tiempo; no afirmar RTO medido |

## Productos exigidos por el documento base

1. Suite reproducible Compose, configuraciones saneadas y script de validación.
2. Informe de avance con prueba de falla, resultado, limitaciones y reversión (ver [informe E3](ENTREGA3.md), [operación](OPERACION-E3.md)).
3. Demostración técnica: dos backends; generar tráfico, detener/degradar uno, comprobar continuidad, reincorporar y explicar **SPOF del proxy**.

## Seis evidencias mínimas a cerrar

- [ ] Compose + variables de ejemplo sin secretos, coherentes con lo instalado.
- [x] HAProxy config validada con `haproxy -c` en ejecución, **sin recargar** ([evidencia](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt)); no confirma retrospectivamente validación antes de recargas pasadas.
- [x] Secuencia versionada de ocho solicitudes 4 web1 / 4 web2.
- [x] Pruebas archivadas de falla y reintegración (secuencias HTTP), **pero faltan logs DOWN/UP y marca de la acción**.
- [x] [Mismo upload NFS servido por **ambos** nodos](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt), SHA-256 igual en las tres ubicaciones.
- [x] [Matriz de flujos permitidos y bloqueados](MATRIZ-FLUJOS-E3.md), con resultados comprobados y flujos adicionales pendientes de verificar.

## Alcance de otras entregas

**Entrega 4** exige observabilidad con panel/alertas, respaldos automatizados de DB+archivos+config y restauración con RPO/RTO medidos; la verificación de TAR web ([10.313 archivos idénticos, 0 diferencias](../evidencias/e3/extraccion-aislada-wordpress-vm279-20261021.txt)) y la [recuperación DB](../evidencias/e3/restauracion-mariadb-docker.txt) son evidencias adicionales valiosas, pero **no sustituyen** ninguna de las evidencias mínimas E3.

No afirmar HA integral, RTO/RPO medidos, pruebas no realizadas ni que fixes Codex estén desplegados. La rama de auditoría es propuesta: las VMs de producción siguen trabajando con sus configuraciones existentes.
