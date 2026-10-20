# Prueba reproducible — Base de datos separada

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Comprobar que MariaDB productiva reside en `.60`, escucha por la red interna y que la VM web puede alcanzarla sin exponer credenciales en el repositorio.

## Validación operativa en VM .60

Las cuentas operativas no ejecutan `sudo mariadb` directamente. Para comprobar el estado del servicio se utiliza un script fijo propiedad de root autorizado por la política de sudo limitada:

```bash
sudo /usr/local/sbin/nodosur-db-check
```

El script comprueba:

- estado activo de MariaDB;
- listener en `10.33.199.60:3306`;
- versión de MariaDB;
- existencia de la base `nodo_sur_final`.

Resultado validado: MariaDB activo y listener únicamente en la dirección interna configurada.

## Inspección administrativa de la base

La inspección directa mediante el cliente `mariadb` se reserva para la cuenta temporal de revisión docente `tas_revision` o la cuenta bootstrap/recovery de `.60`, ambas con sudo completo:

```bash
sudo mariadb
```

```sql
USE nodo_sur_final;
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema='nodo_sur_final';
EXIT;
```

Estado validado: la base `nodo_sur_final` contiene 52 tablas.

## Prueba negativa controlada desde .58

Se utiliza un usuario inexistente y una contraseña ficticia; **no se emplean credenciales reales**.

```bash
mariadb \
-h db.nodosur07.tas \
-u evidencia_tas \
-p'NO_ES_UNA_PASSWORD_REAL' \
-e 'SELECT 1;'
```

Resultado esperado: `Access denied`.

En `.60`, una cuenta perteneciente a `systemd-journal` puede revisar el evento sin elevar privilegios:

```bash
journalctl -u mariadb --since '2 minutes ago' --no-pager \
| grep -i 'Access denied'
```

Resultado validado el 08-09-2026: MariaDB registró el rechazo para `evidencia_tas` desde `10.33.199.58`.

## Interpretación

La prueba negativa demuestra simultáneamente que `.58` alcanza `.60:3306`, MariaDB recibe la conexión, aplica autenticación y registra el rechazo. No demuestra permisos del usuario real de aplicación; esos se validan por separado sin publicar su contraseña.

La separación entre validación operativa e inspección administrativa evita entregar a las cuentas del equipo una consola MariaDB ejecutada arbitrariamente como root.
