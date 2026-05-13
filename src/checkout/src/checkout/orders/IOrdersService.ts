

import { ExistingOrder } from './ExistingOrder';
import { Checkout } from '../models/Checkout';

export interface IOrdersService {
  create(checkout: Checkout): Promise<ExistingOrder>;
}
