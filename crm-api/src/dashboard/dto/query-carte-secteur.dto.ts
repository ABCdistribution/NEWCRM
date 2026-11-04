import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class QueryCarteSecteurDto {
  @ApiPropertyOptional({ description: 'Restreindre à une région (doit être dans le périmètre de l’appelant)' })
  @IsOptional()
  @IsUUID()
  regionId?: string;

  @ApiPropertyOptional({ description: 'Restreindre à un secteur (doit être dans le périmètre de l’appelant)' })
  @IsOptional()
  @IsUUID()
  secteurId?: string;
}
