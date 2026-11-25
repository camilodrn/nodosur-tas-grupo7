# E5 — Ensayo de incidente, recuperación y restauración

**Grupo 7 · TAS EIN-090B · 25/11/2026.** Ensayo previo a la defensa del 27/11; no es evidencia de una defensa ya realizada. Horarios UTC (Chile continental UTC−3 en la fecha del ensayo). Registro retrospectivo de terminales, API de Prometheus y Mailpit y capturas de Grafana compartidas durante el ensayo; no contiene salidas inventadas ni credenciales.

## Estado inicial

- BIND9 respondió autoritativamente a la consulta A de nodosur07.tas: IP de HAProxy 10.33.195.194; NOERROR, aa, TTL 3600.
- Cliente Fedora: tienda y Grafana HTTP 200; Store API producto 45 (Taller de alfarería), HTTP 200, 0,543994 s.
- Prometheus: 12/12 targets disponibles, mysql_up=1, cuatro sondas HTTP/DNS exitosas, ninguna alerta activa. El panel de targets del tablero muestra ocho objetivos filtrados por tipo, no el total de Prometheus.
- VM279: MariaDB en contenedor nodosur-db-staging, saludable; volumen productivo independiente; systemd oneshot con RemainAfterExit, Compose con único servicio mariadb, reinicio Docker deshabilitado. Exporters independientes.
- Respaldo automático del 25/11 a las 04:02:02: 52 declaraciones CREATE TABLE, GZIP válido. Réplica SFTP exitosa. SHA-256 local y remoto coincidente: 8e6451d28e1dd1b164876298c00e8ab35eff63f46c7a81a96bd2dc061ff245b2.

## Incidente autorizado de disponibilidad

Se programó un intento de arranque de emergencia a cinco minutos mediante temporizador transitorio systemd. Se detuvo el servicio nodosur-db-prod.service, cuya acción ExecStop ejecuta Compose stop. No se eliminó el volumen. Recuperación manual antes del temporizador; no se ha verificado aquí su registro posterior.

| Hora UTC | Evidencia |
|---|---|
| 12:50:10 | Orden de detención |
| 12:50:11 | Contenedor Exited (0) |
| 12:50:18.926 | Web1 DOWN; check HTTP 500 |
| 12:50:19.165 | Web2 DOWN; check HTTP 500; sin backends disponibles |
| 12:50:32.963 | HAProxy registra HTTP 503 para producto 45 |
| 12:50:53.134 | activeAt de alerta MariaDB y dos instancias HTTP |
| 12:52:03.497 | Mailpit recibe FIRING MariaDB |
| 12:53:03.157 | Mailpit recibe FIRING HTTP (dos instancias) |
| 12:54:38 | Orden manual de arranque |
| 12:54:44 | Contenedor healthy; Web1 y Web2 UP con checks 200 |
| 12:54:56.197 | HAProxy registra HTTP 200 para producto 45 (Web2) |
| 12:56:03.154 | Mailpit recibe RESOLVED HTTP |
| 12:56:03.469 | Mailpit recibe RESOLVED MariaDB |
| 12:56:33 | Comienza comprobación posterior: mysql_up=1, cuatro sondas exitosas, sin alertas activas |

Durante la falla: mysql_up=0 y sondas HTTP=0; sondas DNS=1. HAProxy respondió 503 al retirar ambos backends, cuyos checks devolvieron 500. El gráfico histórico de los ocho targets filtrados permaneció en 1: exporter accesible no equivale a servicio funcional. No se reinició WordPress, DNS ni HAProxy durante la recuperación.

**Mediciones del escenario:** aproximadamente 42 s hasta activeAt y 112 s hasta recepción de la primera notificación desde la detención confirmada; aproximadamente 6 s entre orden de arranque y ambos backends UP; 4 min 45 s entre detención y primera prueba funcional exitosa registrada. Esta última incluye el tiempo deliberado de diagnóstico y espera de alertas; no es una garantía universal de RTO ni una medición continua del instante exacto de recuperación. Mailpit es recepción SMTP interna de laboratorio, no entrega externa a personas.

## Restauración de datos en copia de evaluación

Prueba distinta del incidente de disponibilidad. En VM279 se creó el contenedor nodosur-e5-evaluacion con red none, sin puertos publicados, volumen independiente nodosur-e5-evaluacion-data, límite 512 MiB RAM y 0,5 CPU. Se verificaron 0 tablas antes y 52 después de importar el respaldo automático del 25/11. Se creó un registro académico en wp_options: ID 8603, nombre nodosur_e5_testigo, valor NODOSUR-E5-RECUPERACION-20261125.

Se generó un respaldo específico de evaluación el 25/11 a las 12:31 UTC, permisos 600, 384 KiB, GZIP válido, testigo presente. SHA-256: aeb7c21e64147c018070dd8c6378e839ec7ab3ed02a6b505a4cdc1c2e7550699.

- Eliminación limitada al registro exacto en la copia: 1 fila eliminada; 0 testigos presentes.
- Restauración del respaldo completo en la misma copia: 12:34:26–12:34:29 UTC, real 2,924 s.
- Validación: mismo ID, nombre y valor recuperados, 52 tablas; ambos contenedores healthy en el corte posterior.

La copia no está conectada a un CMS. Se verificó recuperación del dato por SQL y, en otro ensayo, recuperación de la operación CMS productiva. No se ha medido la pérdida efectiva de transacciones de negocio en un incidente de producción; no presentar RPO integral ni tiempo SQL como RTO integral.

## Mejora posterior de Grafana

Se respaldó el JSON original (22 paneles) fuera del directorio provisionado y se añadió un panel histórico de ancho completo con mysql_up, dos sondas HTTP y dos DNS. Nuevo JSON: 23 paneles, versión 2, sintaxis válida, actualización mediante provisionamiento sin reiniciar Grafana. Captura posterior muestra las cinco series y el intervalo del incidente. SHA-256 de archivo instalado y publicado idéntico: 589b6857241d80f0500820a3a6054fcdb152359f61802edd8e8590a81bf3beaf. Commit 34d8d06b34f975de445ae08c31cdb653b1bade9c.

## Defensa del 27/11

La pauta del aula pide demostrar servicios, registro A, incidente de BD en entorno de evaluación acordado, restauración de un dato en copia de evaluación, validación funcional final y defensa individual. Acordar el entorno y la interrupción con el docente; no asumir que la autorización del ensayo se extiende a la defensa. Preparar acceso desde el cliente de evaluación, mostrar configuración real del registro A y estado de las cinco VM. Repetir la restauración SQL exclusivamente en la copia aislada. No publicar respaldos, secretos ni capturas administrativas sin saneamiento. No se modifica el informe E1–E4 ya entregado.
