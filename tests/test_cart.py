"""
Tests del servicio cart, accesible vía proxy del UI en /api/carts/*.

El proxy reescribe: /api/carts/{id}/items -> carts:8080/carts/{id}/items
Shape del Item (verificado en src/cart/app/models.py):
  { "itemId": str, "quantity": int, "unitPrice": int }
"""
import requests
import pytest


def test_cart_items_vacio(ui_url, customer_id):
    resp = requests.get(f"{ui_url}/api/carts/{customer_id}/items", timeout=10)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_cart_agregar_item(ui_url, customer_id):
    resp = requests.post(
        f"{ui_url}/api/carts/{customer_id}/items",
        json={"itemId": "test-product-1", "quantity": 2, "unitPrice": 999},
        timeout=10,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["itemId"] == "test-product-1"
    assert body["quantity"] == 2


def test_cart_item_persiste(ui_url, customer_id):
    # Depende de test_cart_agregar_item — pytest corre los tests en orden
    # de definición dentro del mismo archivo, así que este va después.
    resp = requests.get(f"{ui_url}/api/carts/{customer_id}/items", timeout=10)
    assert resp.status_code == 200
    items = resp.json()
    ids = [i["itemId"] for i in items]
    assert "test-product-1" in ids


def test_cart_borrar_item(ui_url, customer_id):
    resp = requests.delete(
        f"{ui_url}/api/carts/{customer_id}/items/test-product-1",
        timeout=10,
    )
    assert resp.status_code == 202


def test_cart_health_check_no_verifica_postgres(ui_url, customer_id):
    """
    Bug documentado: el endpoint /health del servicio cart devuelve 200
    aunque la conexión a PostgreSQL esté caída (src/cart/app/main.py, @app.get('/health')).

    Este test usa GET /api/carts/{id}/items como indicador real de conectividad:
    si cart no puede hablar con Postgres, este endpoint devuelve 500, no 200.
    Es una verificación más confiable que el propio /health del servicio.

    El /health del cart no es accesible vía proxy del UI de todos modos
    (el proxy solo expone /carts/*, no la raíz del servicio).
    """
    resp = requests.get(f"{ui_url}/api/carts/{customer_id}/items", timeout=10)
    assert resp.status_code == 200, (
        "Cart no puede conectarse a PostgreSQL — "
        "el health check del servicio no detecta esto (bug conocido)"
    )
