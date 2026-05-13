from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from app.config import settings
from app.router import router

app = FastAPI(title="Cart Service")


@app.on_event("startup")
def startup():
    if settings.cart_persistence_provider == "postgres":
        from app.postgres_service import PostgresCartService
        app.state.cart_service = PostgresCartService()
    else:
        from app.service import InMemoryCartService
        app.state.cart_service = InMemoryCartService()


@app.get("/topology")
def topology():
    return {"provider": settings.cart_persistence_provider}


@app.get("/health")
def health():
    return {"status": "UP"}


app.include_router(router)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")
