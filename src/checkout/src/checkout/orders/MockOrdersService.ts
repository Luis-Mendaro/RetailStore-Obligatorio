

import { Checkout } from '../models/Checkout';
import { ExistingOrder } from './ExistingOrder';
import { IOrdersService } from './IOrdersService';
import { v4 as uuidv4 } from 'uuid';

export class MockOrdersService implements IOrdersService {
  async create(checkout: Checkout): Promise<ExistingOrder> {
    return {
      id: uuidv4(),
      shippingAddress: {
        firstName: checkout.shippingAddress.firstName,
        lastName: checkout.shippingAddress.lastName,
        email: checkout.shippingAddress.email,
        address1: checkout.shippingAddress.address1,
        address2: checkout.shippingAddress.address2,
        city: checkout.shippingAddress.city,
        zipCode: checkout.shippingAddress.zip,
        state: checkout.shippingAddress.state,
      },
      items: checkout.items,
    };
  }
}
