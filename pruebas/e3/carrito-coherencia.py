import json
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = "/wp-json/wc/store/v1"
SERVERS = {
    "web1": "10.33.199.58:18081",
    "web2": "10.33.199.62:18080",
}

def api(server, path, token=None, payload=None):
    headers = {
        "Host": "nodosur07.tas",
        "X-Forwarded-Proto": "https",
        "Cache-Control": "no-store",
    }
    data = None
    if token:
        headers["Cart-Token"] = token
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode()

    req = Request(
        f"http://{SERVERS[server]}{ROOT}{path}",
        headers=headers,
        data=data,
        method="POST" if payload is not None else "GET",
    )
    try:
        with urlopen(req, timeout=15) as response:
            return json.load(response), response.headers.get("Cart-Token")
    except HTTPError as e:
        raise RuntimeError(f"{server}: HTTP {e.code}") from e

products = json.loads(
    Path("/tmp/nodosur-products-web1.json").read_text()
)

eligible = [
    p for p in products
    if p.get("type") == "simple"
    and p.get("is_purchasable") is True
    and p.get("is_in_stock") is True
]

if not eligible:
    raise SystemExit("No hay producto simple apto para probar.")

product = eligible[0]
print(f"Producto de prueba: {product['name']} (ID {product['id']})")

cart, token = api("web1", "/cart")
if not token or cart.get("items"):
    raise SystemExit("No se obtuvo una sesión nueva y vacía.")

print("1. Carrito vacío creado en web1: OK")

added = False
verified = False

try:
    cart, _ = api(
        "web1", "/cart/add-item", token,
        {"id": product["id"], "quantity": 1}
    )
    added = True

    matches = [
        x for x in cart.get("items", [])
        if x["id"] == product["id"] and x["quantity"] == 1
    ]
    if len(matches) != 1:
        raise RuntimeError("No se confirmó el producto en web1.")

    print("2. Producto agregado en web1: OK")

    cart, _ = api("web2", "/cart", token)

    matches = [
        x for x in cart.get("items", [])
        if x["id"] == product["id"] and x["quantity"] == 1
    ]

    if len(matches) != 1:
        raise RuntimeError("El carrito no coincide en web2.")

    print("3. Producto visible desde web2: OK")
    verified = True

finally:
    if added:
        cleaned = False
        for server in ("web2", "web1"):
            try:
                cart, _ = api(server, "/cart", token)
                for item in cart.get("items", []):
                    if item["id"] == product["id"]:
                        api(
                            server, "/cart/remove-item", token,
                            {"key": item["key"]}
                        )
                cart, _ = api("web1", "/cart", token)
                if not cart.get("items"):
                    cleaned = True
                    print(f"4. Carrito limpiado mediante {server}: OK")
                    break
            except Exception as e:
                print(f"Aviso durante limpieza en {server}: {e}")

        if not cleaned:
            print("ADVERTENCIA: limpieza del carrito no confirmada.")

if verified and cleaned:
    print("RESULTADO: COHERENCIA DEL CARRITO CONFIRMADA")
else:
    raise SystemExit("La prueba no se completó correctamente.")
