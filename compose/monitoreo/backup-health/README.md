# Nodo Sur E4 - Salud de respaldos

## Objetivo

Monitorizar la integridad SHA-256 y antigüedad de los
respaldos remotos recibidos en VM268.

El monitor no genera respaldos ni realiza restauraciones.

## Componentes

Servidor: VM268, nodo DNS/NFS y respaldos.

Archivos instalados:

- /usr/local/sbin/nodosur-backup-health
- /etc/systemd/system/nodosur-backup-health.service
- /etc/systemd/system/nodosur-backup-health.timer

Ejecución diaria: 05:15 UTC.

Publicación de métricas:

/var/lib/prometheus/node-exporter/nodosur_backup_health.prom

Node Exporter entrega las métricas a Prometheus en VM308.
Grafana las presenta en los paneles 21 y 22.

## Familias

- mariadb: /var/backups/nodosur-remote/archive
- web1: /var/backups/nodosur-remote/web/web1
- web2: /var/backups/nodosur-remote/web/web2
- uploads: /var/backups/nodosur-remote/web

## Métricas

nodosur_backup_remote_integrity_ok
Valor 1: respaldo más reciente verificado.
Valor 0: respaldo ausente o verificación fallida.

nodosur_backup_latest_verified_timestamp_seconds
Fecha UTC de la copia verificada. Valor 0 si falla.

nodosur_backup_health_collector_last_run_timestamp_seconds
Última ejecución del monitor.

## Alertas

- NodoSurBackupIntegrityFailed: integridad 0 por 2 min.
- NodoSurBackupTooOld: antigüedad mayor a 30 h por 5 min.
- NodoSurBackupMonitorStale: monitor sin actualizar más de 27 h.
- NodoSurBackupSeriesMissing: menos de 4 familias durante 5 min.

Reglas: compose/monitoreo/prometheus/alerts.yml

## Verificación en VM268

Comprobar, sin modificar servicios:

- systemctl status nodosur-backup-health.timer
- systemctl list-timers --all nodosur-backup-health.timer
- systemctl show nodosur-backup-health.service -p Result -p ExecMainStatus
- sudo journalctl -u nodosur-backup-health.service -n 30 --no-pager
- cat /var/lib/prometheus/node-exporter/nodosur_backup_health.prom

En VM308 comprobar las series en Prometheus, los
paneles 21 y 22 de Grafana y las reglas de respaldo.

## Instalación y reversión

Antes de instalar en otra VM, verificar rutas, permisos,
dependencias y configuración del textfile collector.

Respaldar las versiones existentes antes de reemplazar
el script o las unidades systemd.

La instalación requiere copiar los archivos a sus rutas,
recargar systemd y habilitar el temporizador.

Ante problemas posteriores a una actualización,
restaurar los archivos originales, recargar systemd
y validar servicio, temporizador y métricas.

No eliminar respaldos de datos como parte de la reversión.

## Limitaciones

- Verifica únicamente la copia más reciente por familia.
- SHA-256 no demuestra que un respaldo sea restaurable.
- No prueba automáticamente la consistencia interna SQL.
- Los umbrales no prueban cumplimiento del RPO.
- La ejecución manual inicial se validó el 22/11/2026.
- La primera ejecución automática debe verificarse
  independientemente el 23/11/2026.

## Evidencia del 22/11/2026

- Cuatro familias con integridad 1.
- Métricas observadas en Prometheus.
- Dashboard Grafana con 22 paneles.
- Doce reglas de alerta cargadas.
- Cuatro reglas nuevas saludables e inactivas.
- Alerta sintética recibida por Alertmanager y Mailpit.

La simulación verificó el canal de notificación,
no la activación real de las reglas de respaldo.
