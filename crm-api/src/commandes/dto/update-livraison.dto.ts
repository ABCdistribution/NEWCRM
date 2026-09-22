import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { StatutLivraison } from '@crm/database';

/** Mise à jour du suivi de livraison d'une commande (ADV · Direction · ADMIN). */
export class UpdateLivraisonDto {
  @ApiPropertyOptional({
    enum: StatutLivraison,
    description:
      'EXPEDIEE pose dateExpedition (si absente), LIVREE / LIVREE_PARTIELLE posent dateLivraison (si absente)',
  })
  @IsOptional()
  @IsEnum(StatutLivraison)
  statutLivraison?: StatutLivraison;

  @ApiPropertyOptional({ example: '2026-09-15' })
  @IsOptional()
  @IsDateString()
  dateExpedition?: string;

  @ApiPropertyOptional({ example: '2026-09-17' })
  @IsOptional()
  @IsDateString()
  dateLivraison?: string;

  @ApiPropertyOptional({ example: 'GLS' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  transporteur?: string;

  @ApiPropertyOptional({ description: 'N° de suivi transporteur' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  noSuivi?: string;

  @ApiPropertyOptional({ description: 'Commentaire libre (litige, reliquat, point relais…)' })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  commentaireLivraison?: string;
}
