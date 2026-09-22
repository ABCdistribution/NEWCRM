import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateContactDto {
  @ApiPropertyOptional({ example: 'Marie' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  prenom?: string;

  @ApiProperty({ example: 'Durand' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  nom!: string;

  @ApiPropertyOptional({ example: 'Responsable magasin' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  poste?: string;

  @ApiPropertyOptional({ example: 'Chef de rayon DPH', description: 'Type de poste (nomenclature)' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  typePoste?: string;

  @ApiPropertyOptional({ example: '04 72 00 00 00' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  fixe?: string;

  @ApiPropertyOptional({ example: '06 12 34 56 78' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  portable?: string;

  @ApiPropertyOptional({ example: 'marie.durand@magasin.fr' })
  @IsOptional()
  @IsEmail()
  mail?: string;
}

/** Tous les champs de création, mais optionnels. */
export class UpdateContactDto extends PartialType(CreateContactDto) {}
