# Plan de ensayo aislado de reproducibilidad — Nodo Sur E3

**Estado:** diseño de prueba; **aún no ejecutada**. Documento de apoyo a
[Entrega 3](ENTREGA3.md), [guía de reconstrucción](DESPLIEGUE-REPRODUCIBLE-E3.md)
y [rúbrica](RUBRICA-E3.md).

## Qué exige demostrar el criterio

El criterio literal de la rúbrica es **«Aplicación multicontenedor reproducible»**
(15 puntos). No debe confundirse con crear cinco VMs mediante un único
`docker compose up`. Nuestra arquitectura real usa **cuatro proyectos Compose
independientes**, uno por VM Docker (web1, web2, MariaDB y HAProxy); el quinto
host ofrece **BIND9 y NFS nativos**. Compose gestiona el motor local; la
orquestación/provisión de máquinas, red y NFS es externa.

### Evidencia existente

- Cuatro Compose productivos válidos con `docker compose config --quiet`.
- Huellas semánticas web1/web2 iguales entre Fedora y sus VMs.
- Servicios en marcha, MariaDB healthy y volumen histórico confirmado.
- Dos núcleos WordPress 7.1.3 iguales por huellas en 9.817 archivos de
  directorios auditados y archivos principales seleccionados.
- Proxy HTTPS con balanceo, `DOWN` y `UP` observados con caída autorizada.
- DNS, HTTPS, tienda y reparto nuevamente comprobados desde Fedora
  ([evidencia final](../evidencias/e3/validacion-integral-fedora-20261021.txt)).

**Límite:** lo anterior demuestra funcionamiento y coherencia de
configuraciones, pero no acredita por sí solo un despliegue desde cero.

## Prueba propuesta: nuevo entorno aislado

El ensayo deberá desplegar una **copia de laboratorio con datos ficticios**
mediante Compose, reutilizando imágenes y patrones de arquitectura, sin
interferir con las VMs productivas. No sustituye una recuperación completa de
los datos originales.

### Etapa 0 — verificar factibilidad en Fedora (solo lectura)

- Determinar contexto Docker efectivo (Docker Engine vs Docker Desktop), versión
  de Compose, memoria/CPU del daemon, espacio libre y contenedores existentes.
- Verificar disponibilidad de imágenes y elegir un proyecto Compose
  **exclusivo**, no usado por producción.
- No ejecutar todavía `docker compose up`.

### Etapa 1 — preparar definición segura

- Definir proyecto y nombres de redes, volúmenes y contenedores **distintos**
  de `nodosur-db-staging`, `nodosur-web1`, `nodosur-web2` y `nodosur-haproxy`.
- Usar puertos publicados solo en `127.0.0.1`, tras verificar que están libres.
- Mantener secretos **temporales y privados** fuera del repositorio; no imprimir
  contraseñas ni incorporarlas a Git.
- Usar **datos de prueba**. No copiar el volumen
  `nodosur-db-staging_db_stage_data`, ni `wp-config.php` real, ni certificados
  con clave privada, ni exportaciones NFS de producción.
- Aclarar expresamente cualquier sustitución: por ejemplo, un volumen local
  compartido **no demuestra montaje NFS real**; un HAProxy de laboratorio con
  certificado distinto no demuestra confianza TLS en el laboratorio USM.
- Validar Compose y todas las rutas/variables antes de crear contenedores.

### Etapa 2 — evidencia de despliegue

Solo si la etapa previa resulta satisfactoria:

- Iniciar únicamente el proyecto de laboratorio.
- Verificar contenedores, salud DB, rutas HTTP de los dos WordPress, proxy y
  persistencia **con datos ficticios**.
- Demostrar que el proyecto mantiene su estado de prueba en un reinicio
  controlado del propio laboratorio, si es necesario y seguro.
- Capturar salidas mínimas con fecha, `docker compose ps`, resultados HTTP,
  montajes y nombre de volumen **de laboratorio**, sin secretos.
- Limpiar únicamente los recursos marcados y creados por ese proyecto, con
  revisión explícita antes de borrar volúmenes. Nunca usar `docker volume prune`
  ni `docker compose down -v` desde carpetas productivas.

### Etapa 3 — aceptación y límites

| Evidencia | Éxito mínimo | Límite a declarar |
|---|---|---|
| Configuración | Compose válido y dependencias explícitas | No crea VLAN o VM |
| Contenedores | Servicios de laboratorio ejecutándose | No son los de producción |
| Base de datos | Salud y volumen de ensayo persistente | No restauró BD histórica |
| Dos webs | WordPress responde por cada backend | No certifica plugins o clientes reales |
| Proxy | Encaminamiento y health checks de laboratorio | No certifica TLS público |
| Almacenamiento | Compartición o volumen de ensayo verificado | No prueba NFS del iLab |
| Seguridad | Secretos temporales fuera de Git y binds acotados | No reemplaza firewall de VMs |

**Si no hay recursos o el laboratorio aislado no se completa, no afirmar que
se ejecutó.** Para la defensa presentar honestamente la reproducibilidad
**por host** ya validada y explicar la provisión externa necesaria.

## Prohibiciones productivas

No ejecutar en VM279 acciones capaces de renombrar, borrar o recrear
`nodosur-db-staging_db_stage_data`. No ejecutar `git pull/reset/clean` ni
recrear contenedores en VM263 y VM310 con sus cambios locales de Compose.
No modificar reglas, DNS, TLS, NFS o systemd para perseguir una puntuación
sin un defecto observado y un plan de reversión.
