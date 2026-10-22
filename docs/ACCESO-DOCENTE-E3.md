# Plan controlado de accesos de revisión docente — E3

**Estado: cuentas E3 creadas y validadas por SSH/sudo en las cinco VMs.**
Pendiente: rotación de contraseñas, entrega segura y revocación E2 tras
revisión de dependencias. No se han revocado cuentas anteriores.
No incluir contraseñas, hashes, tokens, claves privadas ni credenciales en Git.

## Antecedente de Entrega 2

El equipo documentó la cuenta temporal de revisión `tas_revision`:
- VM268 (DNS/NFS): SSH + sudo.
- VM263 (web1): SSH + sudo.
- VM279 (MariaDB): SSH + sudo.
- WordPress: cuenta `tas_revision` con rol de administrador.
Se debe confirmar **en los hosts actuales** si sigue vigente.
En octubre se verificaron accesos SSH operativos `tas_revision` a
estas tres VMs; no se ha confirmado su estado en VM308/VM310.
No dar por hecho que los usuarios operativos `nodosur-g7-proxy`
o `nodosur-g7-web2` sean cuentas exclusivas del docente.

## Cuentas E3 creadas y acceso SSH/sudo comprobado (22/10/2026)

**Realizado por el equipo en las VMs vía VPN; transcripción aportada al chat.**
Se creó `tas_revision_e3` con HOME y shell Bash en cada máquina. Se
añadió al grupo `sudo` y a `ssh-nodosur` únicamente donde este
grupo existe y es necesario para `AllowGroups`.

| VM | Resultado de creación | Resultado de conexión y autorización |
|---|---|---|
| VM268 DNS/NFS | `tas_revision_e3` creado, `sudo,ssh-nodosur` | SSH correcto, `sudo -n id -u` = 0 |
| VM263 Web1 | `tas_revision_e3` creado, `sudo,ssh-nodosur` | SSH correcto, `sudo -n id -u` = 0 |
| VM310 Web2 | `tas_revision_e3` creado, `sudo` | SSH correcto, `sudo -n id -u` = 0 |
| VM279 MariaDB | `tas_revision_e3` creado, `sudo,ssh-nodosur` | SSH correcto, `sudo -n id -u` = 0 |
| VM308 HAProxy | `tas_revision_e3` creado, `sudo` | SSH correcto, `sudo -n id -u` = 0 |

**Verificación: 5/5 accesos SSH y sudo funcionales.** El código `0`
es UID efectivo root, no una garantía de que todos los servicios
funcionan ni de mínimo privilegio.

**Seguridad pendiente antes de entrega:** las cuentas recibieron
contraseña durante `passwd` interactivo, sin revelar la clave en
salidas. Una contraseña temporal débil y compartida entre hosts fue
propuesta explícitamente por el operador en chat: debe considerarse
expuesta; **rotar con contraseñas largas únicas por VM, fuera de la
conversación y repo, y entregarlas por canal seguro**. Si la política
institucional exige identidades/privilegios acotados, coordinar
con el docente antes de compartir cuentas con sudo completo.

**No realizado todavía:** revocar `tas_revision` E2, inspeccionar la
dependencia exacta de `nodosur-web1.service` y `nodosur-db-stage.service`
/ `nodosur-db-prod.service` en `/home/tas_revision`, entregar credenciales
al profesor, verificar usuario WordPress administrativo, comprobar si
existen llaves SSH E2 aún autorizadas ni validar sesión docente desde
su red. No borrar HOME E2 ni cambiar usuarios operativos del equipo.

## Auditoría de cuentas efectiva (22/10/2026)

Consulta de solo lectura ejecutada por el equipo, desde Fedora VPN, en las
cinco VMs. No se crearon ni modificaron usuarios.

| VM / hostname observado | Usuario E2 `tas_revision` | Privilegio visto | Usuario E3 `tas_revision_e3` |
|---|---|---|---|
| VM268 `nodosur-g7` | existe UID 1002 | miembro de `sudo`; `sudo -l` permite `(ALL : ALL) ALL` | ausente |
| VM263 `nodosurtas07` | existe UID 1001 | miembro de `sudo`; `sudo -l` permite `(ALL : ALL) ALL` | ausente |
| VM279 `svr-db-nodosur07` | existe UID 1001 | miembro de `sudo`; `sudo -l` permite `(ALL : ALL) ALL` | ausente |
| VM310 `nodosur-g7-web2` | ausente | no aplica | ausente |
| VM308 `nodosur-g7-proxy` | ausente | no aplica | ausente |

En VM268/263/279 `tas_revision` pertenece además a `users`,
`systemd-journal`, `ssh-nodosur` y `nodosur-ops`.
Que aparezcan reglas `sudoers` más específicas **no limita**
`(ALL : ALL) ALL`, por lo que el acceso de revisión antiguo
equivale a administración completa de esos hosts.

En VM310 y VM308 se usaron cuentas operativas existentes
(`nodosur-g7-web2`, `nodosur-g7-proxy`) para auditar,
**no consta que sean cuentas del docente y no deben revocarse**.

**Antes de provisionar `tas_revision_e3`** verificar las políticas
efectivas `sshd` (`AllowUsers`, `AllowGroups`, `Match`,
autenticación por llave o contraseña), los grupos realmente presentes,
y las dependencias de servicios en directorios personales de usuarios
antiguos. No copiar ciegamente grupos `nodosur-ops` o `sudo`
sin confirmar su necesidad. El equipo aún no ha hecho cambios.

## Destinos E3 y accesos a probar

| VM | IP administración | Rol |
|---|---|---|
| VM268 | 10.33.195.205 | DNS / NFS |
| VM263 | 10.33.195.202 | WordPress web1 |
| VM310 | 10.33.195.208 | WordPress web2 |
| VM279 | 10.33.195.226 | MariaDB |
| VM308 | 10.33.195.194 | HAProxy / TLS |

Crear, si está autorizado por la USM y el equipo, una identidad
temporal **diferenciada de la revisión E2** (nombre propuesto:
`tas_revision_e3`) en los cinco hosts donde proceda, y una cuenta
WordPress separada solo si el docente necesita revisar el panel.

1. **Inventario de solo lectura**: existencia de usuarios, grupos,
   privilegios sudo/SSH, perfiles de acceso, rutas de los servicios,
   y cuentas operativas que NO deben revocarse por accidente.
2. **Confirmar necesidades del docente**: SSH por VPN, inspección
   de configuración, uso de sudo para Docker/iptables/systemctl,
   interfaz de WordPress y ventana de vigencia. Un miembro del equipo
   conservará acceso administrativo independiente.
3. **Provisionar accesos nuevos**: contraseñas/llaves únicas y seguras
   mediante canal privado, sin valores en pantalla, logs ni Git.
   Permisos mínimos compatibles con la verificación: si se exige sudo
   administrativo o Docker, documentar que equivalen prácticamente
   a control privilegiado del host. No añadir sin criterio al grupo docker.
   Mantener firewall/VPN/SSH de la USM intactos.
4. **Prueba positiva antes de cualquier revocación**, idealmente
   con sesión nueva desde VPN y terminal administrativa de respaldo:
   SSH a las cinco VMs, comandos autorizados de solo lectura
   (Compose, NFS, DB, HAProxy, reglas), panel WordPress si procede.
   Probar los permisos realmente necesarios con la nueva identidad.
5. **Entrega segura**: inventario de acceso + username/host/función,
   método VPN y fecha de caducidad/revocación, por canal institucional;
   claves/contraseñas por un canal seguro separado o individual.
   No colocar contraseñas en el README, evidencia ni issues/PR.
6. **Retiro de E2 solo cuando corresponda**: tras aceptación de
   accesos E3 y confirmar que el docente no necesita mantener
   acceso al historial E2, **bloquear** la cuenta E2 sin borrar
   de inmediato su HOME ni ficheros que pudieran depender de ella.
   Revisar propiedad, servicios systemd, repos y procesos antes
   de eliminar a largo plazo. Considerar panel WordPress por separado:
   reasignar contenido si existiera y evitar borrado de publicaciones.
7. **Reversión y cierre**: si falla la nueva cuenta, revertir
   únicamente el cambio de acceso usando cuenta operativa independiente.
   Al finalizar la ventana de evaluación, revocar E3 y registrar
   fecha y alcance, conservando auditabilidad sin secretos.

## Inspección preliminar segura, por cada VM

```bash
echo '=== Cuentas de revisión registradas ==='
for usuario in tas_revision tas_revision_e3; do
  if getent passwd "$usuario" >/dev/null; then
    id "$usuario"
    sudo -l -U "$usuario" 2>&1 | head -n 20
  else
    echo "$usuario: ausente"
  fi
done
```

**Precaución**: la inspección no crea, bloquea ni cambia contraseñas.
No ejecutar `userdel -r`, `deluser --remove-home`, rotaciones de
credenciales de servicio ni cambios SSH antes de verificar dependencias.

## Relación con la rúbrica E3

- **Segmentación / secretos**: acceso docente separado y temporal,
  sin credenciales en el repositorio, privilegios justificados.
- **Reproducibilidad**: documentar preparación de accesos y provisión
  de secretos externos; el aprovisionamiento manual explícito y
  repetible es distinto de un ajuste oculto, pero no sustituye
  reconstrucción limpia de todo el entorno.
- **Demostración**: comprobar antes de la entrega que la identidad
  docente puede ejecutar las verificaciones de implementación.
