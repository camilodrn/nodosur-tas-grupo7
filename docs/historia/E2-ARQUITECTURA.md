# Arquitectura actual

```text
Cliente/revisor
  │
  │ DNS TCP/UDP 53
  ▼
VM .59 — BIND9
10.33.195.205 / 10.33.199.59
  │
  │ A nodosur07.tas → 10.33.195.202
  ▼
VM .58 — Apache + PHP-FPM + WordPress/WooCommerce
10.33.195.202 / 10.33.199.58
  │
  │ db.nodosur07.tas → 10.33.199.60:3306
  ▼
VM .60 — MariaDB
10.33.195.226 / 10.33.199.60
```

## Separación de roles

La separación de DNS, web y base de datos reduce acoplamiento operacional y evita concentrar todos los servicios en una única VM. La base de datos no se expone al cliente: el tráfico de aplicación usa la red interna.

## Estado actual vs. arquitectura objetivo

La arquitectura actual todavía mantiene SPOF por rol: existe un único DNS, un único backend web y una única base de datos. HAProxy, segundo backend, NFS compartido y monitoreo centralizado corresponden a evolución posterior y no se declaran como implementados en esta entrega.
