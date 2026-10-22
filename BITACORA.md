# Bitácora técnica de incidentes

**Contexto:** los incidentes enumerados a continuación pertenecen principalmente a la fase de plataforma base (E2). Algunas correcciones (como el DNS que apuntaba directamente a VM263 o el LVM local) no describen E3. Consultar [ARQUITECTURA.md](ARQUITECTURA.md) y [estado E3](docs/ENTREGA3.md).

---


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
