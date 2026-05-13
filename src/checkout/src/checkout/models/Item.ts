

import { ApiProperty } from '@nestjs/swagger';
import { ItemRequest } from './ItemRequest';

export class Item extends ItemRequest {
  @ApiProperty({ type: 'integer' })
  totalCost: number;
}
