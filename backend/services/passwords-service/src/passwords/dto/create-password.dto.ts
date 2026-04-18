import { IsBase64, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreatePasswordDto {
  @IsString()
  @IsNotEmpty()
  platform!: string;

  @IsString()
  @IsNotEmpty()
  label!: string;

  @IsBase64()
  ciphertext!: string;

  @IsBase64()
  iv!: string;

  @IsOptional()
  @IsString()
  algorithm?: string;
}
