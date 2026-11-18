import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEmail,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { LigneCommandeApkDto } from './create-commande-apk.dto';

/** Modification d'une commande EN_ATTENTE : seuls les champs fournis changent (`null` efface commentaire / e-mail). */
export class UpdateCommandeApkDto {
  @ApiPropertyOptional({ type: [LigneCommandeApkDto], description: 'Remplace toutes les lignes' })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => LigneCommandeApkDto)
  lignes?: LigneCommandeApkDto[];

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string | null;

  @ApiPropertyOptional({ description: 'Date de saisie (ISO)' })
  @IsOptional()
  @IsDateString()
  dateCommande?: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsEmail({}, { message: 'Adresse e-mail invalide' })
  @MaxLength(254)
  emailValidation?: string | null;

  @ApiPropertyOptional({ nullable: true, description: 'yyyy-mm-dd ; null efface la date ET le motif', example: '2026-12-01' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'nePasLivrerAvant : date au format aaaa-mm-jj' })
  nePasLivrerAvant?: string | null;

  @ApiPropertyOptional({ nullable: true, maxLength: 200 })
  @IsOptional()
  @IsString()
  @MaxLength(200, { message: 'motifNePasLivrerAvant : 200 caractères maximum' })
  motifNePasLivrerAvant?: string | null;
}

export class EnvoyerMailCommandeApkDto {
  @ApiProperty({ description: 'Adresse du client à qui envoyer la commande pour validation' })
  @IsEmail({}, { message: 'Adresse e-mail invalide' })
  @MaxLength(254)
  email!: string;
}
