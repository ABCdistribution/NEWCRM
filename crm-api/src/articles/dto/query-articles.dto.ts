import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBooleanString, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class QueryArticlesDto {
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

  @ApiPropertyOptional({ description: 'Recherche sur code article / libellé / code-barres' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filtrer par statut actif ("true"/"false")' })
  @IsOptional()
  @IsBooleanString()
  actif?: string;

  @ApiPropertyOptional({ description: 'Ne renvoyer que les produits en rappel ("true")' })
  @IsOptional()
  @IsBooleanString()
  rappel?: string;

  @ApiPropertyOptional({ description: 'Ne renvoyer que les produits en promotion en cours OU mis en avant (PEM) ("true")' })
  @IsOptional()
  @IsBooleanString()
  promo?: string;

  @ApiPropertyOptional({ description: 'Ne renvoyer que les produits de cette marque (identifiant)' })
  @IsOptional()
  @IsUUID()
  marqueId?: string;
}
