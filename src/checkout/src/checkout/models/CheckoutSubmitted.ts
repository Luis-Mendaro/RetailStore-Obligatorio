

import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsString, Min, ValidateNested } from 'class-validator';
import { Item } from './Item';

export class CheckoutSubmitted {
  @IsString()
  @ApiProperty()
  orderId: string;

  @IsString()
  @ApiProperty()
  email: string;

  @ValidateNested({ each: true })
  @Type(() => Item)
  @ApiProperty({ type: [Item] })
  items: Item[];

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
