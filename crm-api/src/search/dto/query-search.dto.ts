import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsString, MaxLength, MinLength } from 'class-validator';

export class QuerySearchDto {
  @ApiProperty({ description: 'Mots recherchés (2 à 80 caractères) ; tous les mots doivent se retrouver', example: 'auchan rouen' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  q!: string;
}
