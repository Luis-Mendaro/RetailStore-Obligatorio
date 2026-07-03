"""
Tests del panel admin (acceso directo vía ADMIN_URL).

Las rutas /admin/api/* requieren autenticación JWT via cookie HttpOnly.
La fixture admin_session (conftest.py) hace el login y conserva la cookie
en un requests.Session(), que se reutiliza en todos los tests de este archivo.
"""


def test_admin_login_exitoso(admin_session):
    # Si admin_session no falló al crearse, el login fue exitoso.
    # Este test lo hace explícito en el reporte de pytest.
    assert admin_session is not None


def test_admin_productos_responde(admin_session, admin_url):
    resp = admin_session.get(f"{admin_url}/admin/api/products", timeout=10)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_admin_ordenes_responde(admin_session, admin_url):
    resp = admin_session.get(f"{admin_url}/admin/api/orders", timeout=10)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_admin_sin_autenticacion_devuelve_401(admin_url):
    import requests
    resp = requests.get(f"{admin_url}/admin/api/products", timeout=10)
    assert resp.status_code == 401
