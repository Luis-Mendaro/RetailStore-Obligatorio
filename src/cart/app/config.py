import os


class Settings:
    port: int = int(os.getenv("PORT", "8080"))
    cart_persistence_provider: str = os.getenv("CART_PERSISTENCE_PROVIDER", "in-memory")
    postgres_host: str = os.getenv("CART_POSTGRES_HOST", "localhost")
    postgres_port: int = int(os.getenv("CART_POSTGRES_PORT", "5432"))
    postgres_db: str = os.getenv("CART_POSTGRES_DB", "cartdb")
    postgres_user: str = os.getenv("CART_POSTGRES_USER", "retail_user")
    postgres_password: str = os.getenv("CART_POSTGRES_PASSWORD", "")


settings = Settings()
