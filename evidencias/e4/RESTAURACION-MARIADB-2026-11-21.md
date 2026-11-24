# E4 — Restauración controlada de MariaDB

- **Proyecto:** Nodo Sur — Grupo 7
- **Fecha:** 21 de noviembre de 2026
- **Servidor:** VM279 — `svr-db-nodosur07`
- **Alcance:** recuperación aislada de la base de datos

## 1. Objetivo

Comprobar que un respaldo reciente de MariaDB puede importarse
en un entorno independiente, recuperar datos identificables y
medir la duración del procedimiento.

No se provocó una falla de producción.

## 2. Respaldo seleccionado

- Archivo: `nodo_sur_final-20261121-040922.sql.gz`
- Ruta: `/var/backups/nodosur/daily/`
- Tamaño: 410168 bytes
- Fecha de modificación: 2026-11-21 04:09:22 UTC
- SHA-256: verificación correcta (`OK`)
- GZIP: verificación correcta (código 0)
- Estructura: 52 declaraciones `CREATE TABLE`
- Sentencias `INSERT INTO`: 32

El número de sentencias INSERT no equivale al número de filas.

El archivo no contenía instrucciones CREATE DATABASE ni USE.
Por ello, se creó una base vacía en el entorno de restauración
antes de importar el respaldo.

## 3. Entorno de restauración

- Imagen: `mariadb:10.11`
- Contenedor: `nodosur-e4-restore-20261121`
- Base de pruebas: `nodosur_e4_20261121`
- Volumen: `nodosur-e4-restore-20261121-data`
- Red Docker: `none`
- Puertos publicados: ninguno
- Límite de memoria: 768 MiB
- Reinicio automático: desactivado

El volumen productivo y la restauración histórica del
5 de noviembre no se utilizaron en este ensayo.

## 4. Ejecución cronometrada

| Hito | Hora UTC |
| --- | --- |
| T0: inicio del procedimiento | 2026-11-21 21:24:33 |
| T1: importación y validaciones completadas | 2026-11-21 21:24:41 |
| Duración observada | **8 segundos** |

Durante el intervalo se inició el contenedor, se esperó
la disponibilidad de MariaDB, se creó la base de pruebas,
se importó el respaldo y se realizaron comprobaciones.

El entorno de Docker, la imagen y el volumen ya estaban
preparados antes de T0.

## 5. Validación de los datos

- Tablas recuperadas: **52**
- Pedido testigo localizado: **#71**
- Estado: `wc-on-hold`
- Total: `2000.00000000`
- Fecha de creación: `2026-09-09 01:11:46 UTC`

El pedido coincide con los datos principales de la compra
histórica documentada durante E1–E2.

La validación se limitó a la estructura de las tablas y a
los campos indicados del pedido. No se realizó una prueba
funcional de WordPress sobre la base recuperada.

## 6. Estado posterior

Después del ensayo:

- Contenedor de restauración: `exited`
- Red del contenedor: `none`
- Volumen de restauración: conservado
- MariaDB productiva `nodosur-db-staging`: `healthy`

No se sustituyó la base de datos de producción.

## 7. Interpretación de RPO y RTO

El tiempo medido de **8 segundos** corresponde exclusivamente
al procedimiento de restauración y validación de MariaDB en un
entorno aislado previamente preparado.

No representa el RTO integral de Nodo Sur: no incluye la
reconstrucción de WordPress, archivos, configuraciones, DNS,
proxy ni la verificación del flujo comercial completo.

Entre la fecha de modificación del respaldo y T0 transcurrieron
17 horas, 15 minutos y 11 segundos. Esta diferencia permite
estimar la antigüedad del archivo, pero no demuestra la pérdida
efectiva de información ni acredita por sí sola el objetivo RPO.

Para validar el RPO real se necesita definir un instante de falla
y comparar las últimas operaciones presentes en producción con
las recuperadas.

## 8. Conclusión y pendientes

**Resultado:** restauración aislada de MariaDB exitosa.

Se verificaron la integridad del archivo, la importación de
52 tablas, la presencia y contenido del pedido #71 y la duración
del procedimiento.

Pendiente para la recuperación integral:

- Restaurar archivos y configuración junto con la base.
- Verificar el funcionamiento de WordPress sobre lo recuperado.
- Ejecutar una comprobación funcional de la operación comercial.
- Medir RPO y RTO del servicio bajo un escenario de falla definido.

Estos pendientes no invalidan la recuperación aislada, pero
limitan lo que puede afirmarse respecto de la plataforma completa.
