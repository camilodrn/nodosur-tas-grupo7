# Matriz de cumplimiento E3 y evidencia

**La rúbrica oficial no está en el repositorio ni fue proporcionada.** Esta matriz provisional cubre las áreas solicitadas y demostrables; no inventa criterios oficiales, números, ponderaciones ni puntajes. Al obtener el enunciado, añadir la correspondencia exacta y revisar requisitos que aquí podrían faltar.

Estados: **Evidenciado** = salida histórica versionada, no repetida por la auditoría; **Parcial** = cubre una parte; **Reportado** = declaración del equipo sin salida completa; **Local** = revisión/prueba de archivos; **Pendiente** = falta comprobación.

| Área a mapear a la rúbrica oficial | Estado | Evidencia real | Pendiente / aceptación |
|---|---|---|---|
| Roles distribuidos de cinco VMs | Parcial | Compose, inventario, commits `ce28d3f`, `02bac3e`, `2a91ad3`, `c7e8311` | Captura por VM: hostname, IP, SO, recursos y contenedores efectivos |
| Contenedores y aislamiento | Local / parcial | Seis Compose válidos; [tests](../tests/test_e3.py) verifican aislamiento de identidades/volumen | Ejecutar imágenes y validar digests/usuarios, redes y mounts en destino |
| DNS autoritativo y nombre estable | Local / reportado | Zona E3 `.194` validada con named-checkzone; [registro E3](ENTREGA3.md) | `dig` UDP/TCP, AA/SOA y rechazo de recursión/AXFR en VM268 |
| HTTPS y redirección | Parcial | [6 respuestas HTTPS](../evidencias/e3/https-haproxy.txt), configuración HAProxy | Capturar 301/Location, certificado público SAN/vigencia y validación sin `-k` |
| Balanceo roundrobin | Evidenciado; 5/5 reportado | [8 peticiones, 4/4](../evidencias/e3/balanceo-roundrobin.txt) | Capturar diez peticiones 5/5 si se exige; no atribuirlas al archivo de ocho |
| Retiro de backend caído | Parcial | [8 respuestas web1](../evidencias/e3/failover-web2-detenido.txt) | Comando/horario de parada, log DOWN, tiempo y ausencia de fallos durante detección |
| Recuperación de backend | Parcial | [8 respuestas 4/4](../evidencias/e3/recuperacion-web2.txt) | Log UP, hora y medición RTO; no inferir arranque automático |
| Estado WooCommerce compartido | Evidenciado para carrito | [carrito postmigración](../evidencias/e3/carrito-coherencia-postmigracion.txt) | Sesiones autenticadas/checkout concurrente, salts/plugins coherentes si rubricados |
| NFS RW y persistencia | Reportado / local | Bind uploads en ambos Compose; precheck nuevo; commits `667d7d9`, `8b067ef` | `/etc/exports`, fstab reales, UID/GID, marcador cruzado, arranque sin NFS en clon |
| Persistencia MariaDB | Parcial | Volumen Compose y [restauración](../evidencias/e3/restauracion-mariadb-docker.txt) | Confirmar nombre real, digest y continuidad después de reinicio; evitar nueva DB vacía |
| Firewall Docker | Parcial / local | [web→DB permitido, proxy bloqueado](../evidencias/e3/firewall-db-tras-reinicio.txt); simulaciones de políticas | Reglas/contadores, matriz completa, revalidación tras reinicio de cada rol |
| SSH, cuentas y mínimo privilegio | E2 histórico; E3 pendiente | [pruebas E2](../pruebas/ssh-firewall.md), ejemplos sudo | Estado efectivo de cinco VMs, ownership, acceso Docker, cuentas temporales y revocación |
| Respaldos automáticos | Parcial | [backup staging anterior exitoso](../evidencias/e3/backup-mariadb-systemd.txt); nuevo timer propuesto | Planificación productiva efectiva, última ejecución, frecuencia y alerta |
| Copia remota e integridad | Reportado | [declaración en E3](ENTREGA3.md), nombre de backup y 52 tablas | Unidad/script remoto saneado, transporte, ruta archive, SHA/GZIP y edad |
| Restauración de DB | Evidenciado para una copia histórica | [52 tablas, red none](../evidencias/e3/restauracion-mariadb-docker.txt) | Repetir sobre último backup productivo en entorno aislado, con comandos y tiempos |
| Recuperación completa | Pendiente | [procedimiento propuesto](RECUPERACION-E3.md) | Copia y ensayo consistente de DB + uploads + configuración + grants; medir RPO/RTO |
| Logs y observabilidad | Parcial | Logging Docker rotado; registros systemd de backup; historial E2 | Correlación E3, alertas de caída/backup/espacio, retención y monitoreo central si exigido |
| Seguridad del repositorio | Local | Barrido heurístico árbol + blobs Git; [salida local](../evidencias/e3/auditoria-local.txt) | Repetir antes de publicar y revisar manualmente adjuntos; no sustituye escaneo de VMs |
| Documentación y reproducibilidad | Local / parcial | README, arquitectura, runbooks, historia E2 preservada y [auditoría](AUDITORIA-E3.md) | Material privado custodiado y configuración externa pendiente; adopción de fixes |
| Aportes/defensa individual | E2 documentado; E3 pendiente | [contribuciones históricas](../CONTRIBUCIONES.md), historial real | Relacionar aportes E3 con evidencia sin asignar autoría ficticia |
| Correspondencia con rúbrica oficial | Pendiente | No se encontró documento oficial | Obtener rúbrica y mapear literalmente cada criterio; no estimar nota |

Las correcciones locales no reemplazan las evidencias de operación. Mantener cada evidencia con fecha, VM, configuración/commit y resultado; excluir tokens, claves, SQL y datos de clientes. El cierre de un pendiente requiere evidencia verificable, no cambiar su etiqueta a “validado”.
