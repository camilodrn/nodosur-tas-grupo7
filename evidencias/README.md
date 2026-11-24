# Evidencias de la entrega

## E4 — noviembre de 2026

- [Restauración SQL del 21/11](e4/RESTAURACION-MARIADB-2026-11-21.md).
- [Trazabilidad HTTP del 22/11](e4/E37-LOGS-TRAZABILIDAD-2026-11-22.md).
- [Índice de resultados y límites E4](../docs/ENTREGA4.md), reconstruido desde el informe y anexos v4.24 entregados al aula. Las demás pruebas referenciadas allí no se presentan como archivos originales ya publicados en Git.

Las capturas originales y los registros complementarios deben sanearse antes de publicarlos. El informe y los anexos fueron entregados por el aula; no se incluyen automáticamente en este repositorio público.

**Nota:** la lista histórica de abajo documenta evidencias de la implementación E2 (Apache/PHP-FPM nativo y LVM). Para E3, con Docker, HAProxy y NFS en cinco VMs, consultar [las pruebas reales de Entrega 3](../docs/ENTREGA3.md) y la carpeta [evidencias/e3](e3/). No utilizar como evidencia E3 los antiguos puertos web directos, logs Apache nativos ni el LV de uploads de E2.

---


Esta carpeta documenta **qué evidencia debe conservarse**, pero no almacena secretos ni capturas con credenciales visibles.

## Evidencias recomendadas

### DNS
- `named-checkconf` sin errores.
- `named-checkzone nodosur07.tas ...` con `OK`.
- `dig` UDP/TCP desde cliente autorizado.
- Consulta temporal registrada por BIND.

### Web/HTTPS
- `apache2ctl configtest` → `Syntax OK`.
- HTTP redirige a HTTPS.
- Portada y `/tienda/` → HTTP 200.
- Evento identificable localizado en `nodosur_ssl_access.log`.

### Base de datos
- MariaDB `active/enabled`.
- Listener `10.33.199.60:3306`.
- DB `nodo_sur_final` y 52 tablas.
- Evento de autenticación fallida controlada desde `.58` registrado en journal.

### SSH/UFW
- `PermitRootLogin no`.
- `AllowGroups ssh-nodosur`.
- Cuentas nominativas presentes.
- UFW sin `OpenSSH Anywhere`.
- Log de rechazo/aceptación que demuestra `AllowGroups`.

### Almacenamiento
- LV `nodosur-uploads` de 20 GiB.
- Montaje por UUID en `wp-content/uploads`.
- `www-data:www-data 755`.
- Escritura como `www-data`.
- Persistencia después de reboot.

## Regla de saneamiento

Antes de subir una captura o salida al repositorio revisar que no aparezcan:

- contraseñas;
- claves privadas;
- tokens;
- salts de WordPress;
- credenciales VPN/iLab/Proxmox;
- cookies/sesiones;
- dumps con datos sensibles.

Cuando una evidencia contenga datos sensibles, debe guardarse fuera de GitHub y referenciarse solamente por nombre o descripción en la documentación de entrega.
