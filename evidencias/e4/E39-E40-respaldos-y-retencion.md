# E39–E40 — Respaldos y retención (23/11/2026)

Resumen público de las transcripciones registradas en el paquete académico; no implica una nueva ejecución.

## E39
- El servicio de respaldo SQL de VM279 se ejecutó automáticamente a las 04:04:27 UTC y finalizó exitosamente. La réplica SFTP se ejecutó entre 04:04:28 y 04:04:29 UTC.
- Se comprobó la copia remota: 339.230 bytes, SHA-256 coincidente, GZIP válido y 52 declaraciones CREATE TABLE.
- Copias Web1, Web2 y uploads: 54.667.953, 54.702.780 y 5.472.565 bytes, respectivamente; SHA-256 y TAR/GZIP verificados. La segunda copia de uploads en VM279 fue manual.
- Las configuraciones de las cinco VM se respaldaron y replicaron manualmente en otro servidor.
- Grafana: respaldo SQLite consistente, 92 tablas, integrity_check=ok y réplica verificada. No se ensayó restauración completa de Grafana.

## E40
- Monitor automático: 05:15:00–05:15:01 UTC, Result=success, estado de salida 0.
- MariaDB, Web1, Web2 y uploads: integrity_ok=1.
- Retención automática: 05:30:00–05:31:30 UTC, Result=success, estado de salida 0. Se registró la eliminación de una copia histórica de octubre.
- Inventario del ciclo: 25 SQL, 21 Web1, 20 Web2 y 21 uploads (87 copias clasificadas como válidas).

Estas pruebas acreditan los ciclos observados, no treinta días continuos de copias, restauración integral ni RPO/RTO de producción.

## Fuentes conservadas en el paquete académico
- E39_Evidencias_Complementarias_2026-11-23.md — SHA-256 `8da5dec646b3bec4243fbe6d40506507feebf462b42a9146cf9f444398d69c7f`.
- E40_Monitor_y_Retencion_Automatica_2026-11-23.md — SHA-256 `3534b2c231460d62783191e449d4fc794edf7476767c76c3566d57a004527c27`.

No se publican respaldos, credenciales ni contenidos de configuración sensibles.
