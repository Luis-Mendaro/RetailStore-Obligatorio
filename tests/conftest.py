import os
import pytest
import requests


@pytest.fixture(scope="session")
def ui_url():
    return os.environ.get("UI_URL", "http://localhost:8080").rstrip("/")


@pytest.fixture(scope="session")
def admin_url():
    return os.environ.get("ADMIN_URL", "http://localhost:8081").rstrip("/")


@pytest.fixture(scope="session")
def customer_id():
    # En CI (Capa 2, ECS persistente) cada run usa un cliente distinto
    # para que los datos de un run no contaminen el siguiente.
    # Localmente y en Capa 1 (docker-compose) queda como "ci-local"
    # porque los datos mueren con el contenedor.
    run_id = os.environ.get("GITHUB_RUN_ID", "local")
    return f"ci-{run_id}"


@pytest.fixture(scope="session")
def admin_session(admin_url):
    # Las rutas /admin/api/* requieren un JWT en cookie HttpOnly.
    # No se puede pasar el token manualmente — hay que hacer login
    # y dejar que requests.Session() maneje la cookie automáticamente.
    username = os.environ.get("ADMIN_USERNAME")
    password = os.environ.get("ADMIN_PASSWORD")
    assert username and password, (
        "ADMIN_USERNAME y ADMIN_PASSWORD deben estar definidos como env vars"
    )
    session = requests.Session()
    resp = session.post(
        f"{admin_url}/auth/login",
        json={"username": username, "password": password},
        timeout=10,
    )
    assert resp.status_code == 200, (
        f"Login de admin falló ({resp.status_code}): {resp.text}"
    )
    return session
