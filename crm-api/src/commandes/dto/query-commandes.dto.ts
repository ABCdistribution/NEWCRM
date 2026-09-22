import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBooleanString, IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { StatutLivraison } from '@crm/database';

export class QueryCommandesDto {
  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @ApiPropertyOptional({ description: 'Recherche sur n° de commande / client (enseigne, raison sociale, code)' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: "true pour n'afficher que les commandes annulées" })
  @IsOptional()
  @IsBooleanString()
  annulees?: string;

  @ApiPropertyOptional({ enum: StatutLivraison, description: 'Filtrer par statut de livraison' })
  @IsOptional()
  @IsEnum(StatutLivraison)
  livraison?: StatutLivraison;
}
