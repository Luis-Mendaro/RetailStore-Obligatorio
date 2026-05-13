import boto3
from boto3.dynamodb.conditions import Key
from app.models import Item, Cart
from app.service import CartService
from app.config import settings


class DynamoDBCartService(CartService):
    def __init__(self):
        kwargs = {"region_name": "us-east-1"}
        if settings.dynamodb_endpoint:
            kwargs["endpoint_url"] = settings.dynamodb_endpoint
        dynamodb = boto3.resource("dynamodb", **kwargs)
        self._table = dynamodb.Table(settings.dynamodb_table_name)

        if settings.dynamodb_create_table:
            self._create_table(dynamodb)

    def _create_table(self, dynamodb):
        try:
            dynamodb.create_table(
                TableName=settings.dynamodb_table_name,
                KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
                AttributeDefinitions=[
                    {"AttributeName": "id", "AttributeType": "S"},
                    {"AttributeName": "customerId", "AttributeType": "S"},
                ],
                GlobalSecondaryIndexes=[{
                    "IndexName": "idx_global_customerId",
                    "KeySchema": [{"AttributeName": "customerId", "KeyType": "HASH"}],
                    "Projection": {"ProjectionType": "ALL"},
                    "BillingMode": "PAY_PER_REQUEST",
                }],
                BillingMode="PAY_PER_REQUEST",
            )
            self._table.wait_until_exists()
        except dynamodb.meta.client.exceptions.ResourceInExistsException:
            pass

    def _pk(self, customer_id: str, item_id: str) -> str:
        return f"{customer_id}:{item_id}"

    def _to_item(self, record: dict) -> Item:
        return Item(
            itemId=record["itemId"],
            quantity=int(record["quantity"]),
            unitPrice=int(record["unitPrice"]),
        )

    def get(self, customer_id: str) -> Cart:
        return Cart(customerId=customer_id, items=self.get_items(customer_id))

    def delete(self, customer_id: str) -> None:
        items = self.get_items(customer_id)
        with self._table.batch_writer() as batch:
            for item in items:
                batch.delete_item(Key={"id": self._pk(customer_id, item.itemId)})

    def merge(self, customer_id: str, session_id: str) -> None:
        session_items = self.get_items(session_id)
        existing_ids = {i.itemId for i in self.get_items(customer_id)}
        with self._table.batch_writer() as batch:
            for item in session_items:
                batch.delete_item(Key={"id": self._pk(session_id, item.itemId)})
                if item.itemId not in existing_ids:
                    batch.put_item(Item={
                        "id": self._pk(customer_id, item.itemId),
                        "customerId": customer_id,
                        "itemId": item.itemId,
                        "quantity": item.quantity,
                        "unitPrice": item.unitPrice,
                    })

    def get_items(self, customer_id: str) -> list[Item]:
        resp = self._table.query(
            IndexName="idx_global_customerId",
            KeyConditionExpression=Key("customerId").eq(customer_id),
        )
        return [self._to_item(r) for r in resp.get("Items", [])]

    def add_item(self, customer_id: str, item: Item) -> Item:
        self._table.put_item(Item={
            "id": self._pk(customer_id, item.itemId),
            "customerId": customer_id,
            "itemId": item.itemId,
            "quantity": item.quantity,
            "unitPrice": item.unitPrice,
        })
        return item

    def update_item(self, customer_id: str, item: Item) -> Item | None:
        existing = self.get_item(customer_id, item.itemId)
        if existing is None:
            return None
        self._table.update_item(
            Key={"id": self._pk(customer_id, item.itemId)},
            UpdateExpression="SET quantity = :q, unitPrice = :p",
            ExpressionAttributeValues={":q": item.quantity, ":p": item.unitPrice},
        )
        return item

    def get_item(self, customer_id: str, item_id: str) -> Item | None:
        resp = self._table.get_item(Key={"id": self._pk(customer_id, item_id)})
        record = resp.get("Item")
        return self._to_item(record) if record else None

    def delete_item(self, customer_id: str, item_id: str) -> None:
        self._table.delete_item(Key={"id": self._pk(customer_id, item_id)})
