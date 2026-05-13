

import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsString } from 'class-validator';

export class ShippingOption {
  @IsString()
  @ApiProperty()
  name: string;

  @IsInt()
  @ApiProperty({ type: 'integer' })
  amount: number;

  @IsString()
  @ApiProperty()
  token: string;

  @IsInt()
  @ApiProperty({ type: 'integer' })
  estimatedDays: number;
}
