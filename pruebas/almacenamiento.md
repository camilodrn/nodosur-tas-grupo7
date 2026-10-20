# Prueba reproducible — Almacenamiento WordPress

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Comprobar que `wp-content/uploads` utiliza un volumen LVM dedicado, persiste mediante `/etc/fstab` y mantiene permisos adecuados para WordPress.

## Estado esperado en VM .58

Las comprobaciones que requieren inspección de LVM, propietarios o cambio de identidad deben ejecutarse con `tas_revision` o la cuenta bootstrap/recovery de `.58`, ya que no forman parte del sudo operativo limitado de `nodosur-ops`:

```bash
sudo lvs
findmnt /var/www/html/wp-content/uploads
df -hT /var/www/html/wp-content/uploads
sudo stat -c '%U:%G %a %n' /var/www/html/wp-content/uploads
sudo du -sh /var/www/html/wp-content/uploads
```

Estado validado:

- LV: `nodosur-uploads`.
- Tamaño: 20 GiB.
- Filesystem: ext4.
- Punto: `/var/www/html/wp-content/uploads`.
- Propietario/grupo: `www-data:www-data`.
- Modo: `755`.
- Opciones de montaje observadas: `rw,nosuid,nodev,relatime`.

## Entrada persistente

La entrada validada en `/etc/fstab` identifica el filesystem por UUID:

```text
UUID=7b7c4007-3883-46bf-9a66-a32ab7d5622d /var/www/html/wp-content/uploads ext4 defaults,nodev,nosuid 0 2
```

## Prueba de escritura con identidad de la aplicación

Ejecutar con `tas_revision` o la cuenta bootstrap/recovery:

```bash
sudo -u www-data sh -c \
'echo "storage-ok" > /var/www/html/wp-content/uploads/.tas-storage-test'

sudo -u www-data cat /var/www/html/wp-content/uploads/.tas-storage-test
sudo -u www-data rm /var/www/html/wp-content/uploads/.tas-storage-test
```

No se utiliza `777`.

## Validación de persistencia

Después del reboot del 08-09-2026, el volumen apareció montado automáticamente y la portada/tienda continuaron respondiendo HTTP 200.

## Rollback

Existe respaldo previo de `uploads` fuera del repositorio. Si el montaje fallara: detener Apache, desmontar el LV, restaurar el `fstab` respaldado y volver a iniciar Apache. No publicar respaldos reales en GitHub.
