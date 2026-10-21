# Nodo Sur — Taller de Administración de Sistemas

Proyecto académico del **Grupo 7** para el Taller de Administración de Sistemas, USM, segundo semestre 2026.

## Estado actual

Arquitectura distribuida validada para la entrega:

- **VM .59 — DNS autoritativo / BIND9**
  - Administración/laboratorio: `10.33.195.205`
  - Red interna: `10.33.199.59`
  - Zona: `nodosur07.tas`
- **VM .58 — Web/CMS**
  - Administración/laboratorio: `10.33.195.202`
  - Red interna: `10.33.199.58`
  - Apache + PHP-FPM + WordPress + WooCommerce
- **VM .60 — Base de datos**
  - Administración/SSH: `10.33.195.226`
  - Red interna: `10.33.199.60`
  - MariaDB escucha en `10.33.199.60:3306`

Flujo principal:

`Cliente → DNS .59 → Web .58 → MariaDB .60`

## Controles implementados

- DNS autoritativo para `nodosur07.tas`.
- HTTP redirigido a HTTPS.
- Certificado TLS autofirmado para laboratorio.
- MariaDB separada de la VM web.
- Almacenamiento LVM dedicado para `wp-content/uploads` en la VM .58.
- UFW con accesos por origen y rol.
- SSH restringido a redes VPN/laboratorio y a miembros de `ssh-nodosur`.
- `PermitRootLogin no`.
- Cuentas nominativas para los integrantes del equipo.
- **Sudo limitado por rol** para las cuentas operativas mediante `nodosur-ops`.
- Acceso a logs mediante `systemd-journal` sin entregar root irrestricto.
- Una cuenta bootstrap/recovery por VM con sudo completo.
- Cuenta temporal `tas_revision` con sudo completo exclusivamente para revisión docente.
- Logs y pruebas reproducibles para web, DNS, SSH y MariaDB.
- VMs actualizadas y validadas después del mantenimiento.
- Flujo WooCommerce validado mediante el pedido de prueba `#71`, correlacionado con MariaDB `.60`.
- Contribuciones del equipo registradas en `CONTRIBUCIONES.md` sin inventar reparto retrospectivo.

## Redes relevantes

- VPN USM: `10.30.248.0/24`
- Laboratorio: `10.33.21.0/24`
- Red interna Grupo 7: `10.33.199.56/29`

## Estructura del repositorio

- `configs/`: ejemplos saneados de configuración.
- `configs/sudo/`: política reproducible de privilegios por rol.
- `scripts/`: validaciones no destructivas.
- `pruebas/`: procedimientos reproducibles y resultados esperados.
- `evidencias/`: guía para capturas/logs de evidencia.
- `docs/`: decisiones de arquitectura.
- `BITACORA.md`: incidentes técnicos reales y su resolución.
- `CONTRIBUCIONES.md`: registro de trabajo real por integrante y evidencia disponible.
- `CHECKLIST_ENTREGA2.md`: estado consolidado y pendientes antes de entregar.

## Seguridad

**Este repositorio no debe contener credenciales, contraseñas, salts, claves privadas, dumps con datos sensibles ni archivos `wp-config.php` reales.**

Las configuraciones incluidas están saneadas y usan placeholders cuando corresponde. El barrido pre-publicación verificó además que el árbol actual no contiene archivos `.env`, dumps SQL, claves privadas TLS/SSH ni respaldos sensibles.

## Acceso de revisión

La cuenta temporal `tas_revision` dispone de privilegios administrativos completos en las tres VMs para facilitar la evaluación docente. Sus credenciales se documentan **fuera del repositorio** y deben revocarse al finalizar la evaluación.

Las cuentas del equipo usan privilegios limitados según el rol de cada VM. Los accesos completos de contingencia permanecen en las cuentas bootstrap/recovery y no se consideran cuentas operativas diarias.

## Validación rápida

Desde un cliente de las redes autorizadas:

```bash
bash scripts/validate-web.sh
bash scripts/validate-dns.sh
```

En `.60`, las cuentas operativas pueden ejecutar:

```bash
bash scripts/validate-db-local.sh
```

El script utiliza `/usr/local/sbin/nodosur-db-check`, autorizado por la política de sudo limitada, y no entrega una consola MariaDB ejecutada arbitrariamente como root.

La validación completa de la configuración de SSH mediante:

```bash
bash scripts/validate-ssh-config.sh
```

requiere `tas_revision` o la cuenta bootstrap/recovery de la VM, porque `sshd -t/-T` necesita privilegios que deliberadamente no se entregan a las cuentas operativas.

Las pruebas detalladas están documentadas en `pruebas/`.

## Pendientes de cierre

El flujo empresarial WooCommerce, el registro de contribuciones y el barrido pre-publicación ya están cerrados. El pendiente académico restante es preparar la defensa individual.
