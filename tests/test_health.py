"""
Health checks de los servicios con ALB público.

Los servicios internos (catalog, cart, orders, checkout) no exponen /health
a través del proxy del UI — el proxy solo reescribe rutas bajo /catalog/*,
/carts/*, /checkout/*, /orders/*. Su disponibilidad se verifica en los tests
funcionales de cada servicio.
"""


def test_ui_health(ui_url):
    import requests
    resp = requests.get(f"{ui_url}/health", timeout=10)
    assert resp.status_code == 200
    assert resp.text == "OK"


def test_admin_health(admin_url):
    import requests
    resp = requests.get(f"{admin_url}/health", timeout=10)
    assert resp.status_code == 200
    assert resp.text == "OK"
