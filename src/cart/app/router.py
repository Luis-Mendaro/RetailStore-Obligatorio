from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import Response
from app.models import Item, Cart
from app.service import CartService

router = APIRouter(prefix="/carts")


def get_service(request: Request) -> CartService:
    return request.app.state.cart_service


@router.get("/{customer_id}", response_model=Cart)
def get_cart(customer_id: str, svc: CartService = Depends(get_service)):
    return svc.get(customer_id)


@router.delete("/{customer_id}", status_code=202, response_model=Cart)
def delete_cart(customer_id: str, svc: CartService = Depends(get_service)):
    svc.delete(customer_id)
    return Cart(customerId=customer_id)


@router.get("/{customer_id}/merge", status_code=202)
def merge_cart(customer_id: str, sessionId: str, svc: CartService = Depends(get_service)):
    svc.merge(customer_id, sessionId)
    return Response(status_code=202)


@router.get("/{customer_id}/items", response_model=list[Item])
def get_items(customer_id: str, svc: CartService = Depends(get_service)):
    return svc.get_items(customer_id)


@router.post("/{customer_id}/items", response_model=Item, status_code=201)
def add_item(customer_id: str, item: Item, svc: CartService = Depends(get_service)):
    return svc.add_item(customer_id, item)


@router.patch("/{customer_id}/items", status_code=202)
def update_item(customer_id: str, item: Item, svc: CartService = Depends(get_service)):
    if svc.update_item(customer_id, item) is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return Response(status_code=202)


@router.get("/{customer_id}/items/{item_id}", response_model=Item)
def get_item(customer_id: str, item_id: str, svc: CartService = Depends(get_service)):
    item = svc.get_item(customer_id, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/{customer_id}/items/{item_id}", status_code=202)
def delete_item(customer_id: str, item_id: str, svc: CartService = Depends(get_service)):
    svc.delete_item(customer_id, item_id)
    return Response(status_code=202)
