import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { StatutCommandeApk } from '@crm/database';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class LigneCommandeApkDto {
  @ApiProperty({ description: "UUID de l'article commandé" })
  @IsUUID()
  articleId!: string;

  @ApiProperty({ minimum: 1, description: 'Quantité commandée (unités)' })
  @IsInt()
  @Min(1)
  quantite!: number;

  @ApiPropertyOptional({ description: 'Tarif affiché à la saisie (indicatif — la facturation reste ERP)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  prixIndicatif?: number;
}

export class CreateCommandeApkDto {
  @ApiProperty({
    description:
      "Identifiant généré côté mobile — clé d'idempotence et pont IDCRM avec la commande Minos (10 caractères max)",
    maxLength: 10,
  })
  @IsString()
  @Matches(/^[A-Za-z0-9]{4,10}$/, { message: 'idCommandeApk : 4 à 10 caractères alphanumériques' })
  idCommandeApk!: string;

  @ApiProperty({ description: 'UUID du magasin commandeur' })
  @IsUUID()
  clientId!: string;

  @ApiProperty({ description: 'Date de saisie sur le terrain (ISO)' })
  @IsDateString()
  dateCommande!: string;

  @ApiPropertyOptional({ description: 'Commentaire libre' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({
    enum: StatutCommandeApk,
    default: StatutCommandeApk.VALIDEE,
    description:
      "EN_ATTENTE : brouillon modifiable, jamais transmis à l'ERP tant qu'il n'est pas validé ; VALIDEE (défaut) : commande ferme",
  })
  @IsOptional()
  @IsEnum(StatutCommandeApk, { message: 'statut : EN_ATTENTE ou VALIDEE' })
  statut?: StatutCommandeApk;

  @ApiPropertyOptional({ description: 'Adresse du client pour la validation par mail (pré-remplie depuis sa fiche)' })
  @IsOptional()
  @IsEmail({}, { message: 'Adresse e-mail invalide' })
  @MaxLength(254)
  emailValidation?: string;

  @ApiPropertyOptional({ description: 'Ne pas livrer avant ce jour (yyyy-mm-dd, pas dans le passé) — motif obligatoire', example: '2026-12-01' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'nePasLivrerAvant : date au format aaaa-mm-jj' })
  nePasLivrerAvant?: string;

  @ApiPropertyOptional({ maxLength: 200, description: 'Motif du « ne pas livrer avant » (texte libre, 200 caractères max)' })
  @IsOptional()
  @IsString()
  @MaxLength(200, { message: 'motifNePasLivrerAvant : 200 caractères maximum' })
  motifNePasLivrerAvant?: string;

  @ApiProperty({ type: [LigneCommandeApkDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => LigneCommandeApkDto)
  lignes!: LigneCommandeApkDto[];
}
