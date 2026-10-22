# Guion de demostración técnica — Entrega 3 (12–15 minutos estimados)

**Este es un plan, no una bitácora de acciones ya realizadas.** Revisar el estado del laboratorio antes de la defensa. No automatizar una falla sin autorización del equipo/docente. Ejecutar los comandos desde el host indicado, usando una cuenta autorizada y VPN; no mostrar secretos ni `docker inspect` sin formato.

## Objetivo de cada etapa

| Tiempo orientativo | Criterio de rúbrica | Qué demostrar |
|---|---|---|
| 0–1:30 | Disponibilidad/documentación | Diagrama: VM268 DNS/NFS, VM308 HAProxy, VM263/310 WordPress, VM279 MariaDB; SPOF explícitos |
| 1:30–3:00 | Reproducibilidad | Cuatro Compose por host, imagen/mounts/variables no secretas/volúmenes y archivo externo de secretos; script de preflight por rol |
| 3:00–5:00 | HAProxy/TLS | DNS A; HTTP 301; HTTPS 200, certificado autofirmado; `haproxy -c`; balanceo `X-NodoSur-Backend` |
| 5:00–7:00 | Dos backends | `/tienda/` e imagen NFS en web1/web2: HTTP 200 |
| 7:00–9:00 | Persistencia | MariaDB shared y volumen existente, digest idéntico de la misma imagen vía dos web; evidencia histórica de carrito |
| 9:00–10:30 | Seguridad | `DOCKER-USER`, origen solo proxy, secretos fuera de repo, `uploads` deniega ruta PHP y permite imágenes |
| 10:30–14:30 | Falla/recuperación | **Opción predeterminada sin interrupción:** mostrar la evidencia del 21/10 con logs `DOWN/UP`, 8/8 HTTPS 200 vía web1 y posterior balanceo 4/4. **Solo si docente/equipo autorizan y hay tiempo:** ejecutar nueva falla controlada de web2 con recuperación |
| 14:30–15:00 | Límites | HAProxy/DB/DNS/NFS siguen siendo SPOF; `HEAD /` no certifica salud integral |

La duración es aproximada; si el docente concede menos tiempo, priorizar **TLS + reparto + evidencia de falla/recuperación + persistencia**. La caída en vivo no es requisito para recrear una falla que ya quedó documentada: será una opción únicamente si es solicitada y autorizada.

## Evidencia alternativa de reproducibilidad (sin arriesgar producción)

Si preguntan cómo sabemos que los Compose pueden levantar la capa Docker, mostrar el [ensayo aislado ejecutado en Fedora](ENSAYO-REPRODUCIBILIDAD-E3.md) y su [evidencia de persistencia y reincorporación](../evidencias/e3/persistencia-reinicio-ensayo-fedora-20261021.txt): cuatro contenedores, MariaDB healthy, WordPress inicializado en ambos backends, SQL, uploads con SHA-256, conservación tras reinicio, Web1 `DOWN`/`UP` y balanceo posterior 4/4. **No repetir el reinicio ni la caída durante la defensa** salvo solicitud y autorización. El experimento simula servicios en un Docker Engine local: no equivale a reconstruir VLAN, BIND, NFS ni TLS de iLab. Recordar explicar por qué hubo respuestas inicialmente solo de Web2: Web1 todavía no había sido reincorporado por el health check y el script esperaba demasiado poco.

## Comandos de lectura para la demostración

### Desde Fedora o VM308, DNS y publicación

```bash
dig @10.33.195.205 nodosur07.tas A +short
dig @10.33.195.205 nodosur07.tas A +short +tcp

# HTTP 301 y HTTPS 200 por IP del proxy manteniendo Host correcto.
curl --noproxy '*' -sSI --resolve nodosur07.tas:80:10.33.195.194 http://nodosur07.tas/ |
  grep -Ei '^(HTTP/|location:)'
curl --noproxy '*' -ksSI --resolve nodosur07.tas:443:10.33.195.194 https://nodosur07.tas/ |
  grep -Ei '^(HTTP/|x-nodosur-backend:)'
```

**Nota de seguridad:** `-k` omite la confianza en la cadena TLS para la demo con certificado autofirmado; no prueba identidad validada por una CA pública. Para comprobar confianza real, usar el certificado público correcto y validado como CA/confiable, no el PEM con clave privada.

### Desde VM308 (es el único host autorizado a contactar backends web directamente)

```bash
# Estado/sintaxis del proxy:
sudo docker inspect --type container nodosur-haproxy -f '{{.State.Status}}'
sudo docker exec nodosur-haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Seis solicitudes al HTTPS público del proxy; esperamos 200 y ambos backend IDs:
for i in 1 2 3 4 5 6; do
  curl --noproxy '*' --resolve nodosur07.tas:443:10.33.195.194 \
    -k -sS -o /dev/null -D - https://nodosur07.tas/ |
    tr -d '\r' | grep -Ei '^(HTTP/|x-nodosur-backend:)'
done

# Por backend: ruta principal, tienda e imagen compartida; URL PHP bloqueada.
for destino in 10.33.199.58:18081 10.33.199.62:18080; do
  echo "Backend: $destino"
  for ruta in / /tienda/ /wp-content/uploads/woocommerce-placeholder-768x768.webp /wp-content/uploads/nodosur-e3-inexistente.php; do
    curl --noproxy '*' --connect-timeout 5 --max-time 15 -sS -o /dev/null \
      -w "$ruta -> HTTP %{http_code}\n" \
      -H 'Host: nodosur07.tas' -H 'X-Forwarded-Proto: https' \
      "http://$destino$ruta"
  done
done
```

Interpretar con honestidad: el `403` contra la ruta PHP **inexistente** de producción no equivale a ejecutar un PHP real en la VM. La [prueba aislada](../evidencias/e3/apache-uploads-http-aislado-20261021.txt) sí verificó `403` para archivo PHP inocuo existente, fuera de producción.

### Desde VM279, MariaDB (sin consultar datos)

```bash
sudo docker inspect --type container nodosur-db-staging -f \
  'Estado={{.State.Status}} Salud={{.State.Health.Status}}'
sudo docker inspect --type container nodosur-db-staging -f \
  '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}Volumen={{.Name}}{{end}}{{end}}'
```

Esperar `running`/`healthy`, volumen `nodosur-db-staging_db_stage_data`. **No mostrar `docker inspect` completo ni variables privadas.**

### Desde web1/web2, reglas efectivas de red y montajes

```bash
sudo systemctl is-active nodosur-docker-firewall.service
sudo iptables -S DOCKER-USER
findmnt -M /srv/nodosur/nfs/uploads -o SOURCE,FSTYPE,OPTIONS
```

No modificar políticas de firewall, NAT o rutas durante la defensa.

## Falla de web2 y reintegración (solo si docente/equipo autorizan otra prueba)

**Prueba histórica ya ejecutada el 21/10/2026:** [evento `DOWN` y continuidad 8/8 vía web1](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt); [reincorporación `UP` y 8/8 HTTPS 200 repartidas 4/4](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt). Estas evidencias pueden mostrarse sin volver a interrumpir web2. No se han medido RTO/RPO formales.

**Condiciones de inicio:** web1 HTTP 200 estable, HAProxy sano, DB healthy, NFS montado en ambos, acceso SSH a VM310 y plan de reversión acordado. Mantener una terminal abierta en VM310 y otra en VM308. Tener tiempo disponible; si una condición falla, **NO iniciar ensayo**.

1. En VM308, registrar hora local `date -Is`; comprobar seis HTTPS 200 alternadas y tomar evidencia de la configuración `inter 3s fall 3 rise 2`.
2. En VM310 y **solo cuando el equipo autorice inyectar la falla**, ejecutar `sudo docker stop --time 10 nodosur-web2`. Esto interrumpe temporalmente web2, no la base de datos ni el NFS. La otra web debe continuar atendiendo.
3. En VM308, registrar ocho respuestas HTTPS con su backend y código HTTP. Buscar **solo eventos de salud**, sin mostrar URLs con datos personales:
   ```bash
   sudo docker logs --since 10m nodosur-haproxy 2>&1 |
     grep -Ei 'Server backend_wordpress/web2 is (DOWN|UP)|Health check for server web2' |
     tail -n 20
   ```
   Si no aparecen estas líneas, documentar la ausencia; no fabricar un evento.
4. En VM310, **recuperar el mismo contenedor** con `sudo docker start nodosur-web2`, comprobar estado `running`, `apache2ctl -t` y portada/imagen reales desde VM308. **No recrear una base de datos ni un volumen.**
5. Repetir seis HTTPS y comprobar si ambos backends volvieron a la rotación. Guardar el evento `UP` si existe, hora y códigos HTTP; evitar calcular RTO a partir de intervalos `fall/rise` que no son medidas observadas.
6. Ante fallo de recuperación, no avanzar a otras VMs. Diagnosticar web2 y solicitar apoyo del equipo conservando web1 y la BD.

**No detener web1, proxy, DNS, NFS o MariaDB para esta prueba.** El criterio evalúa continuidad ante fallo de **un backend**, no destrucción de infraestructura compartida.

## Coherencia de WordPress demostrable en un minuto

Además de NFS, [esta evidencia de lectura de la configuración efectiva](../evidencias/e3/wordpress-opciones-productivas-web1-web2-20261021.txt) muestra desde ambos WordPress 7.1.3, la misma URL pública en `home`/`siteurl`, WooCommerce activo y el mismo destino configurado de MariaDB. Aclara que **una misma BD y un mismo almacenamiento de imágenes** evitan divergencia de productos y uploads, pero no prueban sesiones privadas ni checkout concurrente. Para la defensa, basta mostrar la evidencia versionada: no repetir cambios ni pruebas que generen pedidos.

**Control de esquema adicional:** [Web1 y Web2 comparten los valores `wp_`, WooCommerce `11.1.0`, versión BD WC `11.1.0-1` y versión BD WP `61833`](../evidencias/e3/coherencia-esquema-wp-woocommerce-20261021.txt). Son opciones leídas desde los contenedores reales sin modificar pedidos ni tablas.

## Preguntas que conviene responder brevemente

- **¿Qué diferencia hay entre balanceo y HA?** Roundrobin reparte tráfico entre backends. La tolerancia probada se limita a falla de uno de ellos; HA integral requeriría eliminar los SPOF de HAProxy, DB, DNS y NFS.
- **¿Por qué una BD compartida?** Evita que pedidos y productos diverjan entre dos WordPress; aumenta dependencia de MariaDB única.
- **¿Por qué NFS solo en uploads?** Evita imágenes distintas por backend; plugins/core/configuración siguen locales y necesitan control de versiones/coherencia.
- **¿Qué demuestra el health check?** `HEAD /` con 200 muestra respuesta HTTP del WordPress; no garantiza compras, NFS o DB ante cualquier degradación.
- **¿Por qué el certificado da aviso?** Es autofirmado y el cliente no lo confía automáticamente; TLS cifra el tramo cliente–HAProxy, pero `curl -k` no valida identidad.
- **¿Por qué un Compose por VM?** Docker Compose maneja servicios del motor local, no coordina cinco VMs entre sí. La reproducción completa necesita provisión de red/almacenamiento/secretos.
