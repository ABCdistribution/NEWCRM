import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
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

class LigneCommandeApkDto {
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

  @ApiProperty({ type: [LigneCommandeApkDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => LigneCommandeApkDto)
  lignes!: LigneCommandeApkDto[];
}
