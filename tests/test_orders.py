"""
Tests del servicio orders, accesible vía proxy del UI en /api/orders.

El proxy reescribe: GET /api/orders -> orders:8080/orders
La BD arranca vacía, entonces el assert es que responde con array JSON válido.
"""
import requests


def test_orders_listar(ui_url):
    resp = requests.get(f"{ui_url}/api/orders", timeout=10)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
