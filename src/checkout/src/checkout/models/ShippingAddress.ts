

import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString } from 'class-validator';

export class ShippingAddress {
  @IsString()
  @ApiProperty()
  firstName: string;

  @IsString()
  @ApiProperty()
  lastName: string;

  @IsString()
  @ApiProperty()
  address1: string;

  @IsString()
  @IsOptional()
  @ApiProperty()
  address2: string;

  @IsString()
  @ApiProperty()
  city: string;

  @IsString()
  @ApiProperty()
  state: string;

  @IsString()
  @ApiProperty()
  zip: string;

  @IsEmail()
  @IsOptional()
  @ApiProperty()
  email: string;
}
