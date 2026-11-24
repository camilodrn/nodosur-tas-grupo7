# E42–E43 — Inventario, NTP y HTTPS (23/11/2026)

Registro público resumido de las consultas de solo lectura del 23/11, no de una nueva inspección.

- E42: cinco conexiones SSH autorizadas desde Fedora. Las cinco VM reportaron UTC, NTP=yes y NTPSynchronized=yes. Véase el [inventario](../../INVENTARIO.md). No se midió un desfase independiente.
- Red administrativa: 10.33.195.128/25. Red de servicios: 10.33.199.56/29.
- E43: en Web2 y el proxy, ens18 usa DHCP y ens19 tiene IP fija. No se comprobó reserva DHCP institucional ni persistencia después de reiniciar.
- Desde Fedora, curl negoció TLS 1.3 y el SAN coincidió con el dominio; la verificación estricta terminó en error 60 por certificado autofirmado. No se acredita confianza TLS ni resolución automática por DNS.
- HAProxy 3.2.23: publicación 80→8080 y 443→8443; validación de configuración sin error de sintaxis, con advertencia de formato de log del frontend de métricas.

Fuentes del paquete académico:
- E42_Inventario_y_NTP_Cinco_VM_2026-11-23.md — SHA-256 `0a0490c74f68f7ab293f56ab759b5c03dadf153d9530b8d40faf3ec959993be6`.
- E43_Configuracion_DHCP_y_TLS_2026-11-23.md — SHA-256 `58d51b62cd3adb8ff27de3c2c1e1976960fbbaff564e2ee1127e8e5f41e90770`.
