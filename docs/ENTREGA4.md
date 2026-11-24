# Entrega 4 — observabilidad y continuidad

Corte documental: 23 de noviembre de 2026. El informe acumulativo v4.24 y los anexos fueron enviados al aula ese día. Esta página resume sus resultados sin reproducir credenciales, capturas de cuentas, datos personales ni respaldos. Los resultados son registros retrospectivos del informe, no una nueva ejecución de pruebas desde GitHub.

## Configuración versionada

| Componente | Archivo o directorio |
|---|---|
| HAProxy, ruta Grafana y métricas | [haproxy.prod.cfg](../compose/proxy/haproxy.prod.cfg) |
| Prometheus y targets | [prometheus.yml](../compose/monitoreo/prometheus/prometheus.yml) |
| Reglas de alerta (12 definiciones) | [alerts.yml](../compose/monitoreo/prometheus/alerts.yml) |
| Tablero (22 paneles) | [nodosur-e4.json](../compose/monitoreo/dashboards/nodosur-e4.json) |
| Blackbox Exporter | [blackbox.yml](../compose/monitoreo/blackbox/blackbox.yml) |
| Alertmanager y Mailpit | [compose de alertas](../compose/alertas/compose.yaml) |
| Monitor de respaldos | [backup-health](../compose/monitoreo/backup-health/) |

La lectura del árbol Git confirma 12 definiciones de alertas y 22 paneles. No sustituye la inspección del runtime. La configuración versionada no implica que el conjunto completo se pueda desplegar de cero sin dependencias externas.

## Resultados de las pruebas

| Evidencia del informe/anexos v4.24 | Resultado observado | Límite |
|---|---|---|
| E21, [registro SQL](../evidencias/e4/RESTAURACION-MARIADB-2026-11-21.md) | 52 tablas y pedido 71 recuperados en aislamiento | No mide RTO del CMS |
| E23, E29, E36 | 12/12 targets UP en el corte del 22/11; evolución de 8 a 12 reglas; 22 paneles finales | Estado puntual, no SLO mensual |
| E26, E32, E36 | Avisos sintéticos FIRING/RESOLVED en Mailpit y señales históricas de recuperación | No prueba latencia inicial de un mismo incidente real ni escalamiento humano |
| E37, [trazabilidad](../evidencias/e4/E37-LOGS-TRAZABILIDAD-2026-11-22.md) | Correlación HTTP por identificador de solicitud | No sustituye traza hasta SQL |
| E25, E30 | Recuperación aislada de catálogo y archivo multimedia; 9,37 s de procedimiento local | No es RTO institucional |
| E38 | Testigo previo al respaldo recuperado en un segundo volumen; 0,923 s de importación SQL | No mide pérdida de datos de un incidente integral |
| E39, E40 | Respaldo SQL y réplica automáticos del 23/11; comprobación de cuatro familias y retención ejecutada; 87 copias válidas registradas | Huecos históricos; no acredita 30 días continuos |
| E41, E44, E45 | Stock 4→4→3→4; publicación/consulta y retorno a borrador del producto 79; edición persistente de página 82 | No acredita concurrencia ni cupos de talleres |
| E42, E43 | Inventario de cinco VM, NTP sincronizado; DHCP administrativo y certificado autofirmado | No garantiza IP estable ni confianza TLS |
| E46 | Cuenta histórica del CMS observada con rol Suscriptor | No acredita revocación de contraseña histórica |

Los identificadores se remiten a los anexos enviados por el aula. Salvo los dos registros E21 y E37 enlazados, este índice no afirma que las salidas originales estén publicadas en Git. La revisión final de secretos e historial y la incorporación de las evidencias originales saneadas aún están pendientes.

## Límites operacionales y defensa

- Se demostró continuidad al perder un backend web; HAProxy, MariaDB, DNS y NFS siguen siendo dependencias únicas.
- Disponibilidad mensual ≥99,5 %, detección inicial ≤5 min, RTO integral ≤60 min, RPO ≤24 h y retención continua de 30 días no están acreditados integralmente.
- Para el 27/11, preparar topología y servicios, consulta A del DNS, estado normal de observabilidad, falla controlada de MariaDB, restauración de un dato testigo en entorno de evaluación, validación desde cliente y defensa individual. Son actividades futuras, no pruebas ya ejecutadas.
- No ejecutar operaciones destructivas en producción sin autorización, respaldo verificado, entorno identificado y reversión. No publicar secretos, archivos SQL reales, contraseñas o claves privadas.

Documentación histórica de E3: [arquitectura](../ARQUITECTURA.md), [inventario](../INVENTARIO.md), [pruebas de E3](ENTREGA3.md).

## Identificación de los archivos enviados al aula

La entrega se realizó el 23/11/2026 a las 23:22 (Chile). Las tres copias entregadas se conservaron sin modificaciones y se identifican por SHA-256:

| Archivo | SHA-256 |
|---|---|
| NodoSur_Informe_E1-E4_Grupo7.pdf | `8fa997f3a196d35229243623b7a30d3b2bd98dad984367b3f5ac64cd3d095339` |
| NodoSur_Informe_E1-E4_Grupo7.docx | `0c3f646c921a31001c09639471d21e0f8136712e1a77308abf7302abf61572bb` |
| NodoSur_Anexos_Grupo7.pdf | `526563dd6ebe79a4b66898a27fc04d59ffc41d27f0d227d65a2b07ec330c94ff` |

Se reconstruyó localmente el paquete de respaldo de 66 archivos con estas tres versiones y un manifiesto actualizado de 65 entradas verificadas. El Word anterior de los anexos está identificado como referencia interna, no como una copia del PDF enviado. El ZIP no está publicado en GitHub: contiene material académico, evaluaciones internas y capturas que requieren revisión antes de su publicación abierta. El repositorio público conserva documentación técnica y referencias saneadas.
