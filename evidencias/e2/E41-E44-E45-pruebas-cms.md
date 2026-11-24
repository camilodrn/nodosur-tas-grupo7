# Pruebas funcionales complementarias del CMS (23/11/2026)

Resumen público de los registros y capturas entregados en los anexos. No se incluyen capturas administrativas ni datos de cuentas.

## E41 — RF-03: inventario
Producto simple Miel de Montaña Orgánica, ID 38, con gestión de existencias activa. Pedido de prueba 78, una unidad, sin pago real.

| Estado | Existencias |
|---|---:|
| Inicial | 4 |
| Pendiente de pago | 4 |
| En espera | 3 |
| Cancelado | 4 |

Descuento y restitución sin edición manual del saldo. No demuestra concurrencia, último cupo ni pago real; tampoco se comprobó este pedido directamente en MariaDB.

## E44 — RF-01: catálogo
Producto académico 79 creado como borrador, publicado sin precio, consultado en navegador sin sesión WordPress y devuelto a borrador. Se comprobó título, categoría y descripción. No acredita compra ni acceso fuera de la VPN.

## E45 — RF-04: contenidos
Página académica 82 guardada como borrador en Gutenberg. Se añadió una oración y se comprobó tras recargar; el panel mostró tres revisiones. No se publicó ni se probaron otros roles.

## Referencias al paquete académico
SHA-256 de los registros originales (las capturas se conservan en el paquete privado):
- E41_Registro_RF03_2026-11-23.md: `5523ac237950102a705448538c5ff06eec402b5673c41c16e8d0de22ddbc2da0`.
- E44_RF01_Catalogo_2026-11-23_Registro.md: `48a781f7c09685ba283dcbd6e3152f15dba441b94bf4d15a92a0fd840e21085a`.
- E45_RF04_Contenidos_2026-11-23_Registro.md: `74ac38601a324e3ec38e383f437fe0e70e1b78e5281891ab528d55d93d8c6e66`.
