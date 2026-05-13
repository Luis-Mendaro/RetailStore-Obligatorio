

import { Type } from 'class-transformer';
import { IsString, ValidateNested } from 'class-validator';
import { ShippingOption } from './ShippingOption';
import { ApiProperty } from '@nestjs/swagger';

export class ShippingRates {
  @IsString()
  @ApiProperty()
  shipmentId: string;

  @ValidateNested({ each: true })
  @Type(() => ShippingOption)
  @ApiProperty({ type: [ShippingOption] })
  rates: ShippingOption[];
}
