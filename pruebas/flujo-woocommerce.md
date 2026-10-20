# Flujo empresarial WooCommerce — validado

> Registro histórico E2 (septiembre de 2026). Para la arquitectura y las pruebas E3, consultar [operación E3](../docs/OPERACION-E3.md). Los resultados de este archivo no certifican el estado actual de las cinco VMs.

## Objetivo

Demostrar una transacción identificable de extremo a extremo en la aplicación y localizar el mismo pedido en la base de datos MariaDB separada.

## Resultado de la prueba

Se ejecutó una compra de prueba completa mediante una cuenta de cliente de WooCommerce.

- **Pedido:** `#71`
- **Cliente:** `cliente.prueba`
- **Correo de prueba:** `cliente.prueba@nodosur07.tas`
- **Producto:** `Miel de Montaña Orgánica`
- **Cantidad:** `1`
- **Total:** `$2.000 CLP`
- **Medio de pago:** `Transferencia bancaria directa`
- **Estado mostrado al cliente/administrador:** `En espera`
- **Estado almacenado en WooCommerce HPOS:** `wc-on-hold`

## Evidencias funcionales

La secuencia validada fue:

1. El producto se encontraba publicado en la tienda.
2. Se inició sesión con la cuenta de cliente `cliente.prueba`.
3. Se realizó el checkout con los datos de prueba.
4. WooCommerce generó el pedido `#71` por `$2.000 CLP`.
5. El pedido `#71` quedó visible desde **Mi cuenta → Pedidos**.
6. El mismo pedido quedó visible desde **WooCommerce → Pedidos** en la administración, asociado a `cliente prueba`, con total `$2.000` y estado `En espera`.
7. Finalmente se verificó el mismo ID en la base `nodo_sur_final` alojada en la VM de MariaDB.

## Verificación en MariaDB

WooCommerce utiliza tablas HPOS en esta instalación. Se comprobó su existencia con:

```sql
USE nodo_sur_final;
SHOW TABLES LIKE '%order%';
```

Entre las tablas observadas se encuentran:

```text
wp_wc_orders
wp_wc_order_addresses
wp_wc_order_operational_data
wp_wc_orders_meta
wp_woocommerce_order_items
wp_woocommerce_order_itemmeta
```

La consulta del pedido se puede reproducir de forma acotada con:

```sql
SELECT id,
       status,
       currency,
       total_amount,
       customer_id,
       billing_email,
       date_created_gmt,
       payment_method,
       payment_method_title
FROM wp_wc_orders
WHERE id = 71;
```

Resultado relevante observado:

```text
id:                   71
status:               wc-on-hold
currency:             CLP
total_amount:         2000.00000000
customer_id:          5
billing_email:        cliente.prueba@nodosur07.tas
payment_method:       bacs
payment_method_title: Transferencia bancaria directa
```

## Correlación extremo a extremo

```text
Cliente WooCommerce
        ↓
Tienda / Checkout en VM .58
        ↓
Pedido #71
        ↓
Mi cuenta → Pedidos
        ↓
WooCommerce → Pedidos (administración)
        ↓
wp_wc_orders.id = 71 en MariaDB VM .60
```

El ID `71`, el total `$2.000`, el cliente de prueba y el medio de pago permiten correlacionar el mismo evento entre la interfaz del cliente, la administración de WooCommerce y la base de datos separada.

## Nota sobre fecha y zona horaria

La interfaz muestra el pedido el **8 de septiembre de 2026** en horario local de Chile. MariaDB registra `date_created_gmt`, por lo que puede aparecer como **9 de septiembre de 2026 01:11:46 UTC**. Esto corresponde al mismo instante y no constituye una inconsistencia de datos.

## Seguridad de la evidencia

No se publica un volcado completo de `wp_wc_orders`, porque puede contener registros históricos con correos, IPs y otros datos innecesarios. Para documentación pública se conserva únicamente la fila acotada del pedido de prueba `#71` y se excluyen credenciales y datos no relacionados.

**Estado final: VALIDADO.**
