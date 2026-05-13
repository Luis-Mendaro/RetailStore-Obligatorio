

import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { ShippingRates } from './ShippingRates';
import { ApiProperty } from '@nestjs/swagger';
import { ShippingAddress } from './ShippingAddress';
import { Item } from './Item';

export class Checkout {
  @ValidateNested({ each: true })
  @Type(() => Item)
  @ApiProperty({ type: [Item] })
  items: Item[];

  @ValidateNested()
  @Type(() => ShippingAddress)
  @IsOptional()
  @ApiProperty()
  shippingAddress: ShippingAddress;

  @IsString()
  @IsOptional()
  @ApiProperty()
  deliveryOptionToken: string;

  @ApiProperty()
  @ValidateNested()
  @Type(() => ShippingRates)
  shippingRates: ShippingRates;

  @ApiProperty()
  @IsString()
  paymentId: string;

  @ApiProperty()
  @IsString()
  paymentToken: string;

  @IsInt()
  @Min(0)
  @ApiProperty({ type: 'integer' })
  subtotal: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(-1)
  shipping: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(-1)
  tax: number;

  @ApiProperty({ type: 'integer' })
  @IsInt()
  @Min(-1)
  total: number;
}
