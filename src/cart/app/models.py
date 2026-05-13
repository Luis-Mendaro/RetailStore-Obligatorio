from pydantic import BaseModel


class Item(BaseModel):
    itemId: str
    quantity: int
    unitPrice: int


class Cart(BaseModel):
    customerId: str
    items: list[Item] = []
