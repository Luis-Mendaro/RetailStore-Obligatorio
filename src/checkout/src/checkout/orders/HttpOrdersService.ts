import { Checkout } from '../models/Checkout';
import { IOrdersService } from './IOrdersService';
import { ExistingOrder } from './ExistingOrder';

export class HttpOrdersService implements IOrdersService {
  constructor(private readonly endpoint: string) {}

  async create(checkout: Checkout): Promise<ExistingOrder> {
    const payload = {
      shippingAddress: {
        firstName:  checkout.shippingAddress.firstName,
        lastName:   checkout.shippingAddress.lastName,
        email:      checkout.shippingAddress.email,
        address1:   checkout.shippingAddress.address1,
        address2:   checkout.shippingAddress.address2 ?? '',
        city:       checkout.shippingAddress.city,
        state:      checkout.shippingAddress.state,
        zipCode:    checkout.shippingAddress.zip,
      },
      items: checkout.items.map((item) => ({
        productId:  item.id,
        name:       item.name,
        quantity:   item.quantity,
        price:      item.price,
        totalCost:  item.totalCost,
      })),
    };

    const res = await fetch(`${this.endpoint}/orders`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(payload),
    });

    if (!res.ok) {
      throw new Error(`Orders service responded ${res.status}`);
    }

    return res.json() as Promise<ExistingOrder>;
  }
}
