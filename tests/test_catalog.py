"""
Tests del servicio catalog, accesible vía proxy del UI en /api/catalog/*.

El proxy reescribe: GET /api/catalog/products -> catalog:8080/catalog/products
La BD arranca vacía (no hay seed data), entonces el assert es que el endpoint
responde con un array JSON válido — no que tenga productos.
"""
import requests


def test_catalog_products_responde(ui_url):
    resp = requests.get(f"{ui_url}/api/catalog/products", timeout=10)
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)


def test_catalog_tags_responde(ui_url):
    resp = requests.get(f"{ui_url}/api/catalog/tags", timeout=10)
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)


def test_catalog_size_responde(ui_url):
    resp = requests.get(f"{ui_url}/api/catalog/size", timeout=10)
    assert resp.status_code == 200
