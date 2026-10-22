# Ensayo oral — Entrega 3 Nodo Sur (Grupo 7)

**Propósito:** preparar una explicación natural de 12–15 minutos, con
evidencia real y sin cambios de producción. Basado en la rúbrica
original entregada por el equipo. No es una bitácora ni un puntaje
oficial. Como equipo, adaptar los turnos de palabra a sus integrantes.

## Guion hablado por bloques

| Minutos orientativos | Criterio | Qué explicar y mostrar |
|---|---|---|
| 0:00–1:15 | Presentación y arquitectura | «Nodo Sur es una plataforma WordPress y WooCommerce. En esta entrega pasamos de la instalación tradicional a dos backends Docker detrás de HAProxy, con MariaDB y uploads compartidos. Son cinco VMs: DNS/NFS en VM268, Web1 en VM263, Web2 en VM310, DB en VM279 y HAProxy en VM308.» Mostrar arquitectura. |
| 1:15–2:45 | Reproducibilidad (15) | «No usamos un Compose que cree cinco VMs: son cuatro Compose, uno por host Docker, y BIND9/NFS instalados en su propio host. Documentamos servicios, imágenes, binds, redes externas y archivos secretos que se deben provisionar. En Fedora reconstruimos la capa Docker ficticia; en un proyecto nuevo `uploads-init` terminó automáticamente, MariaDB quedó healthy y ambos WordPress pudieron escribir/leer el mismo archivo con SHA-256 idéntico.» No afirmar reconstrucción total de VMs. |
| 2:45–4:15 | Dos backends (15) | «Los dos WordPress responden al flujo principal. Ambos quedaron en WordPress core 7.1.3 y WooCommerce 11.1.0; comparten DB y uploads. El código central comparado dio huellas iguales en 9.817 archivos. Son independientes como procesos/hosts, pero dependen de DB y NFS comunes.» |
| 4:15–6:15 | HAProxy / TLS / salud (20) | «BIND resuelve el dominio hacia el proxy; DNS no transporta tráfico HTTP. HAProxy redirige 80 a 443, termina TLS, distribuye con roundrobin y agrega `X-NodoSur-Backend`. Chequea `HEAD /` y HTTP 200 (`inter 3s fall 3 rise 2`). El certificado es autofirmado: cifra pero el navegador no lo confía automáticamente.» Mostrar DNS A, 301, varios 200 y header, validador `haproxy -c`. |
| 6:15–8:00 | Persistencia/estado (15) | «Ambos backends usan la misma MariaDB y el mismo directorio NFS de uploads. Verificamos un archivo con SHA-256 idéntico y un flujo concreto de carrito entre web1 y web2. No afirmamos que todas las sesiones autenticadas ni compras concurrentes estén verificadas.» Mostrar volumen **histórico** `nodosur-db-staging_db_stage_data` (solo inspect), NFS y evidencia de hash. |
| 8:00–9:30 | Seguridad (15) | «Los backends internos están restringidos por reglas `DOCKER-USER` al origen del proxy; observamos HTTP 200 desde él y timeout desde otro host. Los secretos quedan fuera de Git. En ambos WordPress se impidió ejecutar PHP en uploads. Creamos accesos temporales nuevos de E3 y caducamos E2, sin borrar los directorios que usan systemd.» Mostrar reglas, existencia de secretos sin imprimirlos y HTTP 403 a ruta PHP. |
| 9:30–11:30 | Falla y recuperación (15) | «Detuvimos de manera controlada Web2. HAProxy la marcó DOWN; después de detectar la falla obtuvimos ocho respuestas 200 desde Web1. Recuperamos Web2, HAProxy registró UP y el tráfico volvió a repartirse 4/4. No medimos RTO/RPO ni garantizamos cero errores durante la detección.» Mostrar logs/versionado. Repetir parada solo si docente y equipo autorizan. |
| 11:30–12:30 | Análisis HA / límites (5) | «Balanceo no significa alta disponibilidad completa. Soportamos la caída de un backend web, no del proxy, MariaDB, DNS ni NFS, que siguen siendo puntos únicos de falla. Para evolucionar haría falta redundancia, replicación/almacenamiento y mecanismos de recuperación verificados.» |
| 12:30–15:00 | Preguntas | Responder desde observaciones; si algo no se probó, decirlo y explicar cómo lo comprobarían. |

## Explicaciones breves para preguntas probables

**¿Por qué cuatro Compose y cinco VMs?** Porque Docker Compose
orquesta contenedores sobre un motor Docker; el host de DNS/NFS usa
servicios nativos, y los Compose de cada uno de los otros cuatro hosts
no provisionan máquinas ni VLAN. Crear las cinco VMs exigiría otras
herramientas de infraestructura o automatización, fuera de E3.

**¿Qué prueba que es reproducible?** Los cuatro Compose productivos
validaron `config --quiet`; en Fedora desplegamos de cero un
proyecto Docker aislado con volúmenes nuevos, `uploads-init`
automático, MariaDB healthy, webs corriendo y archivo compartido
con SHA-256 idéntico. Las VMs y sus datos/secretos requieren
aprovisionamiento externo documentado.

**¿Por qué el Compose WordPress declara 7.1.2 y funciona 7.1.3?**
La imagen Docker declarada sigue siendo 7.1.2, pero el directorio
HTML está persistido mediante bind mount y su WordPress core fue
actualizado a 7.1.3. El 21/10 alineamos Web2 con respaldo y
comprobamos huellas. Una reconstrucción nueva necesitaría
restaurar ese HTML, por lo que no damos por garantizada la igualdad
solo con `docker compose up`.

**¿Qué pasa si falla la DB, NFS o el proxy?** La disponibilidad
del servicio se degrada o interrumpe. Tener dos webs no implica
eliminar esos SPOF.

**¿El health check comprueba WooCommerce completo?** No.
`HEAD /` y HTTP 200 confirman una respuesta HTTP útil para
retirar/reintegrar un backend, no el recorrido de compra,
la base de datos o todos los archivos ante cualquier fallo.

**¿Qué prueba el 403 en uploads?** Que Apache bloquea la solicitud
hacia una ruta PHP bajo uploads. En una prueba aislada se colocó
un PHP inocuo y se confirmó 403; en producción se verificó 403
para una ruta inexistente, sin subir código.

**¿Por qué dice certificado inseguro?** Porque es autofirmado.
TLS cifra el tramo cliente–HAProxy; `curl -k` no verifica la
identidad. La confianza requiere distribuir/validar el certificado
público o usar una CA de confianza.

**¿Qué hicieron con las credenciales del profesor?** Crearon
`tas_revision_e3` en cinco VMs, comprobaron SSH/sudo y
rotaron contraseñas. Caducaron `tas_revision` Linux en los tres
hosts previos preservando el HOME que aún usa systemd; WordPress E2
quedó como suscriptor con sesiones revocadas y E3 administrador,
probado por HTTPS y con rol confirmado en Web2. Entregar contraseñas
**solo por canal privado** y retirarlas tras corrección.

## Qué NO afirmar

- Que las **cinco VMs** fueron creadas desde cero por Compose.
- Que existe **alta disponibilidad integral** o recuperación
  automática de todos los componentes.
- Que TLS autofirmado es confiable sin instalación explícita
  del certificado.
- Que no hubo **ningún error durante la detección** de la falla.
- Que se probaron todas las sesiones, compras concurrentes o
  restauración integrada de la base de datos.
- Que el checkout Git de todas las VMs corresponde ya
  al mismo commit de cierre del repositorio.

## Orden de evidencias recomendado

1. [Arquitectura](../ARQUITECTURA.md) y [guion de comandos de solo lectura](PLAN-DEMOSTRACION-E3.md).
2. [Validación cuatro VMs](../evidencias/e3/validacion-cuatro-vms-config-runtime-20261021.txt) y [reproducción Fedora](ENSAYO-REPRODUCIBILIDAD-E3.md).
3. [Balanceo y HTTP 200](../evidencias/e3/balanceo-roundrobin.txt) y [TLS](../evidencias/e3/http-redirect-y-validacion-proxy-20261021.txt).
4. [Mismo archivo desde NFS/web1/web2](../evidencias/e3/nfs-mismo-archivo-web1-web2-20261021.txt) y [carrito](../evidencias/e3/carrito-coherencia-postmigracion.txt).
5. [Firewall y bloqueos](../evidencias/e3/segmentacion-origen-proxy-vs-dns-nfs-20261021.txt).
6. [DOWN + continuidad](../evidencias/e3/prueba-falla-web2-haproxy-web1-20261021.txt) y [UP + 4/4](../evidencias/e3/wordpress713-recuperacion-web2-haproxy-20261021.txt).

**Práctica sugerida:** explicar cada bloque sin leer más de dos
ideas clave, comprobar que el compañero puede responder una
pregunta de por qué/limitación, y reducir el recorrido en pantalla
antes de repetir una falla en vivo. La defensa debe mostrar
resultados observables, no prometer lo no ensayado.
