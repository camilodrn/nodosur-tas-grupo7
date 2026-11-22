# E37 - Auditoria de logs y trazabilidad

Fecha: 22/11/2026.
Servidor auditado: VM308, proxy y observabilidad.

## Sincronizacion horaria

La VM utiliza UTC y reporta NTPSynchronized=yes.

## HAProxy

Configuracion observada:
- option httplog
- unique-id-format con UUID version 7
- unique-id-header X-Request-ID
- log-format con identificador rid
- encabezado X-NodoSur-Backend

Muestra real de los ultimos registros:
- 600 lineas examinadas.
- 599 lineas con identificador rid.
- 599 identificadores diferentes.

## Correlacion HTTP y TLS

Se realizo una solicitud HTTPS a nodosur07.tas.

Resultado:
- HTTP/2 200.
- Backend seleccionado: web2.
- Cabecera X-Request-ID recibida.
- Coincidencias del identificador en logs HAProxy: 1.

El certificado fue verificado mediante confianza explicita
en su copia publica. Es autofirmado y vigente entre
20/10/2026 y 20/10/2027.

La prueba demuestra correlacion cliente-HAProxy.
No demuestra propagacion hasta los logs de Apache.

## Retencion de registros

Driver Docker observado: json-file.

Con max-size=10m y max-file=3:
- HAProxy
- Grafana
- Prometheus
- Alertmanager
- Mailpit

Sin limites efectivos de rotacion:
- Blackbox Exporter
- Node Exporter de VM308

Espacio de VM308 al auditar: 86 GB disponibles;
ocupacion del sistema de archivos: 7%.

Blackbox tenia aproximadamente 3,4 MB en su archivo
activo y Node Exporter aproximadamente 9,6 KB.

La retencion configurada es por volumen, no por dias.

## Limitaciones y decision

No se demostro correlacion del identificador hasta Apache.
No se audito en esta prueba la retencion de todas las VMs.

Se decidio no recrear los dos exporters ni reiniciar Docker
antes de la entrega, debido al bajo consumo observado.

Pendiente: incorporar limites de rotacion y verificar
su aplicacion efectiva en una ventana de mantenimiento.

No se realizaron cambios en servicios durante la auditoria.
