

import { CheckoutRequest } from '../models/CheckoutRequest';
import { ShippingRates } from '../models/ShippingRates';
import { IShippingService } from './IShippingService';

export class MockShippingService implements IShippingService {
  constructor(private prefix: string) {}

  async getShippingRates(_request: CheckoutRequest): Promise<ShippingRates> {
    return Promise.resolve({
      shipmentId: this.makeid(32),
      rates: [
        {
          name: `${this.prefix}Priority Mail`,
          amount: 10,
          token: 'priority-mail',
          estimatedDays: 10,
        },
        {
          name: `${this.prefix}Priority Mail Express`,
          amount: 25,
          token: 'priority-mail-express',
          estimatedDays: 5,
        },
      ],
    });
  }

  private makeid(length) {
    let result = '';
    const characters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const charactersLength = characters.length;
    for (let i = 0; i < length; i++) {
      result += characters.charAt(Math.floor(Math.random() * charactersLength));
    }
    return result;
  }
}
