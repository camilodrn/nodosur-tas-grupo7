# Evidencias de la entrega

Para E3 consultar [matriz y alcance](../docs/MATRIZ-E3.md). Los `.txt` originales de `e3/` se conservan sin cambios. `e3/auditoria-local.txt` registra únicamente comprobaciones locales. El resto de esta guía procede de E2 y no acredita estado actual de las cinco VMs.

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
