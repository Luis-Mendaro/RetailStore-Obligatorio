

import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsInt, Min } from 'class-validator';

export class ItemRequest {
  @IsString()
  @ApiProperty()
  id: string;

  @IsString()
  @ApiProperty()
  name: string;

  @IsInt()
  @Min(0)
  @ApiProperty({ type: 'integer' })
  quantity: number;

  @IsInt()
  @Min(0)
  @ApiProperty({ type: 'integer' })
  price: number;
}
