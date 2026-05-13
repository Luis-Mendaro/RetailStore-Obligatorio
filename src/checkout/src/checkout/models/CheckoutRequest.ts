

import { Type } from 'class-transformer';
import { ValidateNested, IsOptional, IsString } from 'class-validator';

import { ShippingAddress } from './ShippingAddress';
import { ApiProperty } from '@nestjs/swagger';
import { ItemRequest } from './ItemRequest';

export class CheckoutRequest {
  @ValidateNested({ each: true })
  @Type(() => ItemRequest)
  @ApiProperty({ type: [ItemRequest] })
  items: ItemRequest[];

  @ValidateNested()
  @Type(() => ShippingAddress)
  @IsOptional()
  @ApiProperty()
  shippingAddress: ShippingAddress;

  @IsString()
  @IsOptional()
  @ApiProperty()
  deliveryOptionToken: string;
}
