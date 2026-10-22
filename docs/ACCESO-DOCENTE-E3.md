# Plan controlado de accesos de revisión docente — E3

**Estado: propuesto / pendiente de ejecución y validación.** No afirmar
que existan aún cuentas nuevas ni que se hayan revocado cuentas anteriores.
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
