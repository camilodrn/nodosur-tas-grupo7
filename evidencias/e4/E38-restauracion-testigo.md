# E38 — Recuperación de un dato testigo

Registro público resumido del ensayo aislado en Fedora/Podman del 23/11/2026 (UTC). Fuente: E38_Auditoria_RPO_RTO_Testigo_2026-11-23.md del paquete académico (SHA-256: `58dd304d54b712fdcfeca87861e68f2e79ef3746f86eccbc950cbdaa7368a596`). No es una nueva prueba.

- Se importó la copia SQL del 22/11 en un contenedor MariaDB 10.11 aislado: 52 tablas.
- Se creó una tabla de prueba y un dato identificable **antes** de producir un nuevo respaldo.
- Se comprobó que el dato estaba presente en el respaldo comprimido.
- Se restauró en otro contenedor, con un volumen independiente y sin la base previa.
- La consulta posterior devolvió 53 tablas, un dato testigo y huellas coincidentes.
- La importación SQL tardó 0,923 s; la restauración funcional anterior E30 tardó 9,37 s en otro ensayo local.

No se midió el tiempo desde el primer fallo de negocio en iLab hasta el restablecimiento integral ni la pérdida real de datos de un incidente. El RPO ≤24 h y RTO ≤60 min siguen siendo objetivos no acreditados integralmente. No se incluyen dumps ni datos del negocio.
