import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { StatutCommandeApk } from '@crm/database';
import { IsEnum, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { ModifieDepuisQuery } from '../../common/modifie-depuis';

export class QueryCommandesApkDto extends ModifieDepuisQuery {
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

  @ApiPropertyOptional({ description: 'Filtre sur un magasin' })
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @ApiPropertyOptional({ enum: StatutCommandeApk, description: 'Filtre sur le statut (EN_ATTENTE ou VALIDEE)' })
  @IsOptional()
  @IsEnum(StatutCommandeApk)
  statut?: StatutCommandeApk;
}
