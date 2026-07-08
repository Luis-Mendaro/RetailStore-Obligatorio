"""
Tests del servicio checkout, accesible vía proxy del UI en /api/checkout/*.

El proxy reescribe: /api/checkout/{id} -> checkout:8080/checkout/{id}

GET /api/checkout/{id} devuelve 404 cuando el checkout no existe — eso es
correcto y esperado. Un 404 del servicio prueba que está vivo y puede hablar
con Redis. Un 502/503 indicaría que el servicio está caído.

Nota: checkout es el único servicio cuyo health check responde JSON
{"status":"ok"} en vez de texto plano "OK" (verificado en
src/checkout/src/app.controller.ts). Esa ruta no es accesible vía proxy.
"""
import requests


def test_checkout_servicio_disponible(ui_url, customer_id):
    # 404 es la respuesta esperada cuando no hay checkout para este customer.
    # Cualquier otro código 4xx o 5xx diferente de 404 indica un problema real.
    resp = requests.get(f"{ui_url}/api/checkout/{customer_id}", timeout=10)
    assert resp.status_code in (200, 404), (
        f"Checkout devolvió {resp.status_code} — "
        "se esperaba 200 (existe) o 404 (no existe), no un error de gateway"
    )
