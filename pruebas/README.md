# Guía de pruebas — Nodo Sur

Este directorio contiene materiales de **distintas entregas**, no todos describen el entorno E3 actual.

## Entrega 3 (dos WordPress Docker + HAProxy + NFS)

- [Carrito compartido entre web1 y web2](e3/carrito-coherencia.py): script que **escribe temporalmente** en un carrito. No realiza checkout, pero requiere explícitamente `--permitir-escritura --producto ID` y ejecutarse solo desde una VM con acceso autorizado a ambos backends, en ventana de pruebas. Si falla la red puede requerir revisar la limpieza; no ejecutarlo automáticamente durante una defensa.
- [Informe de resultados existentes](../docs/ENTREGA3.md): balanceo 4/4, failover, reincorporación, TLS, hashes NFS y matriz firewall.
- [Matriz de flujos con pruebas positivas y negativas](../docs/MATRIZ-FLUJOS-E3.md).
- [Validadores no destructivos](../README.md#verificaciones-sin-modificar-las-vms): DNS, web y MariaDB en Docker. Los scripts del repositorio pueden no estar instalados en cada VM.

**No hay que repetir una prueba que altera servicios o escribe datos sin verificar primero la disponibilidad, definir reversión y obtener aprobación del equipo.**

## Material histórico de E2

Los archivos `web-https.md`, `base-datos.md`, `almacenamiento.md`, `dns.md`, `ssh-firewall.md`, `flujo-woocommerce.md`, `logs-observabilidad.md` y `actualizaciones.md` corresponden fundamentalmente al laboratorio previo de **tres VMs**, Apache/PHP-FPM nativo y uploads locales en LVM. Se conservan como historial, pero sus puertos, unidades systemd y rutas no sustituyen las comprobaciones de E3.

Antes de seguir una guía, confirmar la VM, el rol, la fecha y si corresponde a infraestructura instalada o propuesta de auditoría.
