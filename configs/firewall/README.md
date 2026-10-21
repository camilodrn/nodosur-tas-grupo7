# Firewall E3: política y adopción

El estado UFW histórico E2 está [archivado](../../docs/historia/E2-configs-firewall-README.md). No demuestra la política vigente de cinco VMs. Las evidencias E3 solo verifican algunos flujos de DB tras reiniciar Docker; los scripts auditados son una propuesta pendiente de instalar y validar.

| Destino | Puerto | Origen autorizado propuesto | Capa |
|---|---|---|---|
| IP administrativa de cada VM | TCP 22 | VPN `10.30.248.0/24`, lab `10.33.21.0/24` | UFW/INPUT |
| VM268 admin `.205` | UDP/TCP 53 | VPN y lab | UFW/INPUT + ACL BIND |
| VM268 interna `.59` | UDP/TCP 53 | `10.33.199.56/29` | UFW/INPUT + ACL BIND |
| VM268 interna `.59` | TCP 2049 (NFSv4 propuesto) | `.58`, `.62` | UFW/INPUT + exports |
| VM308 admin `.194` | TCP 80,443 | VPN y lab | DOCKER-USER |
| VM263 interna `.58` | TCP 18081 | `.61` | DOCKER-USER |
| VM310 interna `.62` | TCP 18080 | `.61` | DOCKER-USER |
| VM279 interna `.60` | TCP 3306 | `.58`, `.62` | DOCKER-USER |
| VM279 interna `.60` | TCP 13307, solo lab habilitado | `.58`, `.62` | DOCKER-USER |
| Réplica VM279↔VM268 | Pendiente de capturar | Solo extremos y cuenta dedicada | No inferir protocolo/puerto real |

UFW no sustituye el filtro del tráfico publicado por Docker. La biblioteca `nodosur-firewall-common.sh` debe instalarse en `/usr/local/lib/nodosur` junto a los wrappers en `/usr/local/sbin`. Usa `conntrack --ctorigdst/--ctorigdstport --ctdir ORIGINAL`; no depende de `ens18/ens19` y filtra solicitudes al puerto publicado aunque ingresen por otra interfaz.

Cada rol tiene cadena propia `NODOSUR_*`; la transacción `iptables-restore --noflush` reemplaza solo esa cadena y mueve su salto al principio de DOCKER-USER. Un salto **jump (`-j`)** acotado al endpoint permite que un `RETURN` del origen autorizado vuelva a `DOCKER-USER` y continúe evaluando sus demás reglas; las fuentes no autorizadas reciben `DROP`. No usar `goto` (`-g`): permitiría omitir reglas posteriores de `DOCKER-USER`. Esta política debe verificarse con las reglas heredadas del host antes de instalarla. No se vacían cadenas globales ni se cambia la política del host. `-w 5` espera el bloqueo xtables; un fallo devuelve error y systemd no inicia el servicio dependiente.

La propuesta reduce DB a dos clientes y retira la autorización antigua de `.59` en ese endpoint. Confirmar que ningún proceso real dependa de SQL directo desde VM268 antes de adoptarla. La réplica de archivos no necesita SQL por principio, pero su implementación aún no está versionada.

## Validación del operador

Antes y después, guardar `sudo iptables-save` privadamente y comparar. Revisar `sudo iptables -S DOCKER-USER`, cadenas `NODOSUR_*`, contadores `sudo iptables -nvL NODOSUR_DB_PROD`, listeners y pruebas positivas/negativas de [operación](../../docs/OPERACION-E3.md). No ejecutar un flush global ni deshabilitar UFW. El cambio de backend Docker a nftables nativo no está soportado.

Estas reglas cubren IPv4 y puertos publicados por DNAT. No restringen automáticamente conexiones originadas localmente en el mismo host ni acceso directo a IPs de contenedores mediante un modo de routing especial. Mantener el bridge NAT por defecto, sin `allow-direct-routing`, host networking ni publicación IPv6 no inventariada; verificar configuración efectiva. El host y acceso al daemon son parte de la frontera de confianza.

La conectividad SSH, exportaciones NFS, políticas INPUT/OUTPUT, rp_filter y rutas deben verificarse en las cinco VMs; no se modificaron ni se declararon probadas aquí.
