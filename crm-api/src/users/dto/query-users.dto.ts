import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsEnum, IsIn, IsInt, IsOptional, IsString, Matches, Max, Min } from 'class-validator';
import { Role } from '@crm/database';

export class QueryUsersDto {
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

  @ApiPropertyOptional({ description: 'Recherche sur login / nom affiché / email' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ enum: Role, description: 'Filtrer par rôle' })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ description: "Filtrer par secteur (UUID), ou « aucun » pour les comptes sans secteur" })
  @IsOptional()
  @IsString()
  @Matches(/^(aucun|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i)
  secteurId?: string;

  @ApiPropertyOptional({ enum: ['actif', 'inactif'], description: 'Filtrer par statut du compte' })
  @IsOptional()
  @IsIn(['actif', 'inactif'])
  statut?: 'actif' | 'inactif';
}
