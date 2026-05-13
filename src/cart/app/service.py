from abc import ABC, abstractmethod
from app.models import Item, Cart


class CartService(ABC):
    @abstractmethod
    def get(self, customer_id: str) -> Cart: ...

    @abstractmethod
    def delete(self, customer_id: str) -> None: ...

    @abstractmethod
    def merge(self, customer_id: str, session_id: str) -> None: ...

    @abstractmethod
    def get_items(self, customer_id: str) -> list[Item]: ...

    @abstractmethod
    def add_item(self, customer_id: str, item: Item) -> Item: ...

    @abstractmethod
    def update_item(self, customer_id: str, item: Item) -> Item | None: ...

    @abstractmethod
    def get_item(self, customer_id: str, item_id: str) -> Item | None: ...

    @abstractmethod
    def delete_item(self, customer_id: str, item_id: str) -> None: ...


class InMemoryCartService(CartService):
    def __init__(self):
        self._store: dict[str, dict[str, Item]] = {}

    def _cart(self, customer_id: str) -> dict[str, Item]:
        return self._store.setdefault(customer_id, {})

    def get(self, customer_id: str) -> Cart:
        return Cart(customerId=customer_id, items=list(self._cart(customer_id).values()))

    def delete(self, customer_id: str) -> None:
        self._store.pop(customer_id, None)

    def merge(self, customer_id: str, session_id: str) -> None:
        session_items = self._store.pop(session_id, {})
        cart = self._cart(customer_id)
        for item_id, item in session_items.items():
            if item_id not in cart:
                cart[item_id] = item

    def get_items(self, customer_id: str) -> list[Item]:
        return list(self._cart(customer_id).values())

    def add_item(self, customer_id: str, item: Item) -> Item:
        self._cart(customer_id)[item.itemId] = item
        return item

    def update_item(self, customer_id: str, item: Item) -> Item | None:
        cart = self._cart(customer_id)
        if item.itemId not in cart:
            return None
        cart[item.itemId] = item
        return item

    def get_item(self, customer_id: str, item_id: str) -> Item | None:
        return self._cart(customer_id).get(item_id)

    def delete_item(self, customer_id: str, item_id: str) -> None:
        self._cart(customer_id).pop(item_id, None)
