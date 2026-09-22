import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class QueryClientsDto {
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

  @ApiPropertyOptional({ description: 'Recherche sur enseigne / raison sociale / codeAs400' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({
    description: "Filtrer sur le portefeuille d'un code représentant (idCommercial1/2) — ignoré pour un COMMERCIAL (toujours scopé sur son propre code)",
  })
  @IsOptional()
  @IsString()
  repr?: string;

  @ApiPropertyOptional({
    description: 'enrich=1 : ajoute CA mois, Δ N-1, dernière visite, périodicité, CS, alertes, état par magasin',
  })
  @IsOptional()
  @IsString()
  enrich?: string;

  @ApiPropertyOptional({ description: "tous=1 : un commercial voit TOUS les magasins (décochage du filtre « Mes magasins »)" })
  @IsOptional()
  @IsString()
  tous?: string;

  @ApiPropertyOptional({ description: 'avecAdresse=1 : uniquement les vrais points de vente (CP renseigné — exclut les pseudo-clients PLV)' })
  @IsOptional()
  @IsString()
  avecAdresse?: string;
}
