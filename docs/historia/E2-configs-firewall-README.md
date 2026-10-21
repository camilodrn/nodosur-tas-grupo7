# Estado de firewall UFW

Las siguientes reglas resumen el **estado validado** por rol. No contienen secretos.

## VM .58 — WEB/CMS

Permitido hacia `10.33.195.202`:

- TCP 22 desde VPN `10.30.248.0/24`.
- TCP 22 desde laboratorio `10.33.21.0/24`.
- TCP 80 desde VPN `10.30.248.0/24`.
- TCP 80 desde laboratorio `10.33.21.0/24`.
- TCP 443 desde VPN `10.30.248.0/24`.
- TCP 443 desde laboratorio `10.33.21.0/24`.

No existe regla SSH `Anywhere`.

## VM .59 — DNS

Permitido:

- TCP/UDP 53 hacia `10.33.195.205` desde VPN `10.30.248.0/24`.
- TCP/UDP 53 hacia `10.33.195.205` desde laboratorio `10.33.21.0/24`.
- TCP/UDP 53 hacia `10.33.199.59` desde la red interna `10.33.199.56/29`.
- TCP 22 hacia `10.33.195.205` desde VPN y laboratorio.

Existen reglas TCP 80/443 desde VPN asociadas al web anterior de `.59`; se conservan como referencia/rollback y **no representan el servicio web productivo actual**.

## VM .60 — DB

Permitido:

- TCP 3306 hacia `10.33.199.60` desde `10.33.199.58` (WEB productiva).
- TCP 3306 hacia `10.33.199.60` desde `10.33.199.59` (regla heredada/rollback).
- TCP 22 hacia `10.33.195.226` desde VPN `10.30.248.0/24`.
- TCP 22 hacia `10.33.195.226` desde laboratorio `10.33.21.0/24`.

La base de datos no se expone directamente a clientes VPN/laboratorio mediante TCP 3306.

## Verificación

```bash
sudo ufw status numbered
sudo ss -lntp
```

Al eliminar reglas numeradas, volver a ejecutar `ufw status numbered` antes de la siguiente eliminación, porque los índices se renumeran inmediatamente.
