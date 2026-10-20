# Bitácora técnica de incidentes

## 1. Importación SQL y redirección con sudo
- **Síntoma:** permiso denegado al importar un dump mediante redirección `<`.
- **Causa:** la redirección la ejecuta el shell antes de aplicar `sudo` al comando.
- **Corrección:** ejecutar la redirección dentro de un shell elevado, por ejemplo `sudo sh -c 'mariadb ... < archivo.sql'`.
- **Aprendizaje:** elevar el binario no eleva automáticamente las redirecciones del shell.

## 2. Acción MariaDB ejecutada en la VM equivocada
- **Síntoma:** se intentó una operación de MariaDB en la VM web.
- **Causa:** confusión entre la VM web y la VM DB durante la migración.
- **Corrección:** detener la acción, confirmar hostname/IP y ejecutar en `.60`.
- **Validación:** MariaDB productiva quedó separada en `10.33.199.60:3306`.

## 3. MariaDB local habilitada en la VM web
- **Síntoma:** el servicio local quedó habilitado temporalmente.
- **Corrección:** deshabilitar y detener MariaDB local en `.58`.
- **Validación:** `mariadb` local `inactive/disabled` y sin listener 3306.

## 4. Ruta WooCommerce incorrecta
- **Síntoma:** `/shop/` respondía 404.
- **Causa:** el slug real era `/tienda/`.
- **Validación:** `/tienda/` responde HTTP 200.

## 5. Caché DNS después del cutover
- **Síntoma:** el host seguía resolviendo el apex a la IP anterior.
- **Diagnóstico:** consulta directa a BIND devolvía la IP nueva.
- **Causa:** caché local del resolver.
- **Corrección:** `resolvectl flush-caches`.
- **Validación:** resolución a `10.33.195.202` y HTTP 200.

## 6. UFW renumeró reglas después de una eliminación
- **Síntoma:** al borrar por número, una regla HTTP restringida terminó removida accidentalmente.
- **Causa:** los índices de UFW cambian inmediatamente después de cada eliminación.
- **Corrección:** reañadir la regla específica y volver a listar antes de nuevas eliminaciones.
- **Aprendizaje:** preferir comandos semánticos o reconsultar `ufw status numbered` tras cada cambio.

## 7. DNS desde laboratorio no respondía inicialmente
- **Diagnóstico:** revisión de ACL, UFW y tráfico con `tcpdump`.
- **Corrección:** habilitar correctamente la red de laboratorio `10.33.21.0/24` para DNS TCP/UDP 53.
- **Validación:** consultas UDP y TCP respondieron correctamente desde laboratorio.

## 8. Usuario nominativo rechazado por AllowGroups
- **Síntoma:** `cduran` existía y tenía contraseña, pero SSH rechazaba el acceso.
- **Log:** `not allowed because none of user's groups are listed in AllowGroups`.
- **Causa:** faltaba pertenencia a `ssh-nodosur`.
- **Corrección:** agregar el usuario al grupo autorizado.
- **Validación:** login SSH aceptado y registrado en journal.

## 9. Alcance histórico y transición E3 — 20-10-2026

Los incidentes 1–8 pertenecen a E1/E2 y se conservan. El historial de integración incorpora web2 (`790cb71`, `57263de`, `667d7d9`), web1 Docker/NFS (`80df36c`, `8b067ef`), HAProxy (`3511ad6`, `978db35`, `b872379`) y MariaDB Docker (`b9dd173`, `488cb27`). El commit `279466d` documentó la arquitectura final de cinco VMs. La auditoría no repitió las acciones de esos commits.

## 10. Documentación contradictoria tras integrar E3

- **Hallazgo local:** README, arquitectura, inventario y decisiones seguían describiendo tres VMs; el DNS de ejemplo apuntaba a `.202`.
- **Corrección:** documentación E3 y zona de ejemplo `.194`, archivo exacto de la versión E2, etiquetas históricas en las pruebas anteriores.
- **Verificación:** `named-checkzone` del ejemplo y revisión de enlaces/consistencia. La zona de VM268 no fue consultada ni recargada.

## 11. Dependencias de arranque y privilegios

- **Hallazgo local:** drop-ins web exigían `nodosur-docker-firewall.service`, que no existe en el repositorio; las unidades principales no exigían firewall. Compose se ejecutaba como root desde homes de cuentas administrativas/temporales.
- **Corrección:** dependencia explícita por backend, propagación `PartOf` del reinicio Docker, prechequeo NFS real RW y propuesta root-owned `/opt/nodosur`.
- **Alcance:** se verificó el grafo local de nombres. El análisis nativo systemd fue bloqueado por sockets/permisos del entorno; no se simula un arranque exitoso de las VMs.

## 12. Colisión de nombres de producción y staging

- **Hallazgo local:** ambos Compose DB compartían proyecto, contenedor y volumen; el proxy de laboratorio compartía identidad con el productivo.
- **Corrección:** laboratorio con identidades/volumen propios; producción conserva nombre histórico y exige volumen externo existente.
- **Verificación:** parseo de seis Compose y pruebas de aislamiento. El nombre de volumen inferido debe contrastarse con el montaje real antes de instalar; no se creó ni migró una DB.

## 13. Respaldos y validadores

- **Hallazgo local:** backup rechazaba cualquier esquema distinto de 52 tablas, carecía de lock, interpolaba contraseña sin escapar y faltaba unidad base/timer. Validadores web/DNS podían devolver éxito pese a resultados incorrectos; el carrito dependía de un JSON externo en `/tmp`.
- **Corrección:** motor común de backup con lock, escape y aviso de cambio de esquema; servicio/timer propuestos; verificador SHA/GZIP; scripts con retorno significativo y timeouts; carrito con producto por API y habilitación explícita de escrituras.
- **Verificación:** regresiones con datos ficticios y procesos simulados. No se ejecutó backup, importación ni prueba de carrito sobre infraestructura.

## 14. Firewall, uploads y trazabilidad de evidencias

- **Hallazgo local:** reglas dependientes de interfaz y orden parcial, excepción DB heredada para `.59`, falta de prohibición de ejecución de uploads en la configuración versionada.
- **Corrección:** política por endpoint original, cadenas propias actualizadas de forma transaccional y bloqueo Apache en uploads. Cambios pendientes de adopción; no se alteró el firewall local ni remoto.
- **Evidencia:** archivos originales muestran 4/4, 3/3 y ocho respuestas durante falla; 5/5 y backup remoto de 52 tablas son resultados reportados por el equipo. La matriz distingue esas fuentes y conserva los textos originales.

## 15. Cierre de auditoría local

Se trabajó desde `audit/e3-codex` con base `e3/integracion` en `279466d`, árbol inicialmente limpio. Sin SSH, cambios productivos, reinicios, migraciones ni push. [Informe](docs/AUDITORIA-E3.md), [matriz](docs/MATRIZ-E3.md) y [salida local](evidencias/e3/auditoria-local.txt) registran resultados y límites. Los pendientes de laboratorio no se consideran cerrados por haber corregido archivos.
