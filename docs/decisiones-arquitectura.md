# Decisiones de arquitectura — E3

Las decisiones 1–9 originales de E2 se conservan [íntegras](historia/E2-docs-decisiones-arquitectura.md). Lo siguiente distingue implementación reportada de correcciones todavía locales.

| Decisión | Estado | Motivo y coste |
|---|---|---|
| Cinco VMs por rol; dos backends web | Implementada según registros E3 | Tolera caída de un web; no elimina fallos de proxy, DB, DNS o NFS |
| HAProxy con roundrobin y check HTTP 200 | Implementada; evidencia parcial | Distribución sin afinidad; la aplicación debe compartir estado correctamente |
| TLS en HAProxy; HTTP y SQL internos | Implementada | Simplifica certificados; red interna transmite datos sin TLS explícito |
| Certificado autofirmado para apex/www | Reportada y HTTPS evidenciado | Cifrado de laboratorio; requiere instalar confianza y revisar SAN/caducidad |
| MariaDB única por IP interna | Implementada | Mantiene un estado transaccional compartido, con SPOF y restauración manual |
| NFS solo para uploads | Reportada; mounts en Compose | Evita duplicar subidas; plugins/temas/core permanecen locales, exigen coordinación |
| Preservar nombre/volumen productivo de staging original | Propuesta de auditoría | Evita que un renombre cree una DB vacía; se exige volumen externo preexistente |
| Staging y proxy de laboratorio con identidades separadas | Propuesta de auditoría | Impide que un `compose up` de laboratorio reconfigure producción |
| systemd controla arranque; Docker sin auto-restart | Implementada, dependencias corregidas localmente | Ordena firewall/NFS; no ofrece recuperación autónoma de toda caída |
| Código de despliegue root-owned en `/opt/nodosur` | Propuesta de auditoría | Elimina dependencia de cuentas temporales y escritura de código ejecutado como root |
| Reglas propias atómicas en DOCKER-USER | Propuesta de auditoría | Filtra destino original tras DNAT y todas las interfaces; requiere backend iptables |
| Backup transaccional, checksum y prueba aislada | Backup y restauración histórica evidenciados; scripts corregidos | `single-transaction` depende de tablas InnoDB y ausencia de DDL concurrente |
| 52 tablas como línea base, no veto permanente de backup | Propuesta de auditoría | Un plugin puede modificar el esquema; guardar respaldo válido y emitir aviso |
| No conceder Docker genérico mediante sudo | Propuesta operativa E3 | Acceso al daemon equivale a root; usar consultas fijas y código root-owned |

La propuesta de NFS no se presenta como copia de `/etc/exports` productivo. Los salts reales, grants MariaDB, configuración remota de respaldos y certificados deben recuperarse de los custodios autorizados sin versionar secretos. No se inventa automatización para reemplazar componentes que aún no están documentados.

Referencias técnicas primarias consultadas durante la auditoría:

- [Docker: iptables y DOCKER-USER](https://docs.docker.com/engine/network/firewall-iptables/): filtrado anterior a las reglas Docker y destino original mediante conntrack.
- [Manual upstream iptables-restore](https://man7.org/linux/man-pages/man8/iptables-restore.8.html): declarar una cadena propia con `--noflush` reemplaza su contenido conservando otras cadenas.
- [systemd.unit: dependencias y PartOf](https://www.freedesktop.org/software/systemd/man/257/systemd.unit.html): propagación de parada/reinicio; no supervisa por sí sola el proceso interno de un contenedor.
- [Docker Compose: orden y disponibilidad](https://docs.docker.com/compose/how-tos/startup-order/): contenedor iniciado y servicio listo son estados distintos.
- [Entrypoint oficial WordPress](https://github.com/docker-library/wordpress/blob/master/latest/php8.3/apache/docker-entrypoint.sh): un `wp-config.php` existente no se regenera automáticamente a partir de variables.
- [MariaDB: mariadb-dump](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump): alcance de snapshots transaccionales y options files.
