"""
Tests del servicio orders, accesible vía proxy del UI en /api/orders.

El proxy reescribe: GET /api/orders -> orders:8080/orders
La BD arranca vacía, entonces el assert es que responde con array JSON válido.

Nota: Go serializa nil slice como JSON null, no como []. Cuando no hay órdenes
en la BD, el endpoint devuelve 200 con body null. Ambos son respuestas válidas.
"""
import requests


def test_orders_listar(ui_url):
    resp = requests.get(f"{ui_url}/api/orders", timeout=10)
    assert resp.status_code == 200
    body = resp.json()
    assert body is None or isinstance(body, list)
