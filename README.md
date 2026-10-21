# Nodo Sur — Grupo 7, Taller de Administración de Sistemas USM

Entrega 3: **23 de octubre de 2026**. Arquitectura implementada de cinco VMs, según los registros del equipo del 20 de octubre. Esta rama contiene correcciones locales de auditoría; **no se han desplegado en las VMs**.

| VM | Rol E3 | Administración | Red interna |
|---|---|---|---|
| 268 | BIND9, NFS, receptor de respaldos | 10.33.195.205 | 10.33.199.59 |
| 263 | WordPress/WooCommerce web1 Docker | 10.33.195.202 | 10.33.199.58 |
| 310 | WordPress/WooCommerce web2 Docker | 10.33.195.208 | 10.33.199.62 |
| 279 | MariaDB Docker | 10.33.195.226 | 10.33.199.60 |
| 308 | HAProxy Docker, terminación HTTPS | 10.33.195.194 | 10.33.199.61 |

`Cliente → HAProxy → web1/web2 → MariaDB`; BIND resuelve `nodosur07.tas` y `www` al proxy. Ambos backends montan uploads desde NFS en VM268. La tolerancia a fallos cubre un backend web; DNS, NFS, proxy y DB siguen siendo puntos únicos de fallo.

## Documentación de entrega

- [Entrega 3 y alcance de las evidencias](docs/ENTREGA3.md).
- [Arquitectura y flujos](ARQUITECTURA.md), [inventario](INVENTARIO.md) y [decisiones](docs/decisiones-arquitectura.md).
- [Instalación y adopción de las correcciones](docs/INSTALACION-E3.md).
- [Operación, pruebas y diagnóstico](docs/OPERACION-E3.md).
- [Respaldos, recuperación y reversión](docs/RECUPERACION-E3.md).
- [Checklist E3 según la pauta base proporcionada](docs/CHECKLIST-PAUTA-E3.md) y [matriz técnica ampliada](docs/MATRIZ-E3.md).
- [Informe de auditoría P0/P1/P2](docs/AUDITORIA-E3.md) y [bitácora](BITACORA.md).

## Verificación local sin VMs

```bash
bash scripts/validate-repository.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit-secrets.py
```

El validador local requiere Bash y Python 3; Compose, `named-checkzone` y `visudo` se usan si están disponibles y su ausencia se informa como **SKIP**, nunca como aprobación. Las pruebas de regresión requieren el cliente Compose, pero simulan Docker e iptables sin acceder al daemon, red ni servicios del host.

Desde un cliente autorizado, con el certificado público autofirmado validado por un canal confiable:

```bash
NODOSUR_CA_CERT=/ruta/segura/nodosur07.crt bash scripts/validate-web.sh
bash scripts/validate-dns.sh
```

`NODOSUR_INSECURE=1` permite diagnóstico explícito sin validar confianza TLS. No demuestra autenticidad del servidor. La prueba de carrito escribe temporalmente en la aplicación y requiere una ventana de pruebas; no forma parte del chequeo local.

## Estado y límites

Los archivos originales conservan balanceo 4/4, failover con ocho respuestas de web1, recuperación 4/4, HTTPS 3/3, carrito compartido y restauración aislada de 52 tablas. El equipo además reportó balanceo 5/5 y copia remota SHA-256/GZIP de 52 tablas; falta versionar la salida saneada de esas comprobaciones. Ver [matriz](docs/MATRIZ-E3.md).

Las correcciones cierran errores del repositorio, pero requieren adopción y verificación en laboratorio. Faltan la configuración real de exportaciones NFS y de réplica/mantenimiento remoto, los digests de imágenes, pruebas de arranque de las cinco VMs y la rúbrica oficial. No se asigna una nota ni se declara cumplimiento total sin esos elementos.

## Historia y seguridad

E1/E2 se conservan en el historial Git, [documentos históricos](docs/historia/README.md), `pruebas/*.md`, [checklist E2](CHECKLIST_ENTREGA2.md) y [contribuciones](CONTRIBUCIONES.md). En E2 había tres VMs, Apache/PHP-FPM nativo y LVM local; esa arquitectura no describe E3.

No versionar credenciales, salts, claves privadas, `wp-config.php` real ni SQL. Consultar [SECURITY.md](SECURITY.md). Las cuentas docentes y los permisos sudo de las nuevas VMs deben verificarse sin publicar credenciales.
