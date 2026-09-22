import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { StatutOpportunite, TypeOpportunite } from '@crm/database';

export class CreateOpportuniteDto {
  @ApiProperty({ enum: TypeOpportunite, description: 'Référencement · OP · Mise en avant' })
  @IsEnum(TypeOpportunite)
  type!: TypeOpportunite;

  @ApiPropertyOptional({ description: 'UUID du prospect porteur (exactement un de prospectId / clientId)' })
  @IsOptional()
  @IsUUID()
  prospectId?: string;

  @ApiPropertyOptional({ description: 'UUID du client porteur (exactement un de prospectId / clientId)' })
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @ApiPropertyOptional({ type: [String], description: 'UUIDs des articles visés' })
  @IsOptional()
  @IsArray()
  @IsUUID(undefined, { each: true })
  articleIds?: string[];

  @ApiPropertyOptional({ example: 'Référencement gamme solaire été 2027' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional({ description: 'Valeur estimée (€)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  valeurEstimee?: number;

  @ApiPropertyOptional({ description: 'Début de la période (OP / mise en avant)', example: '2026-10-01' })
  @IsOptional()
  @IsDateString()
  dateDebut?: string;

  @ApiPropertyOptional({ description: 'Fin de la période', example: '2026-10-31' })
  @IsOptional()
  @IsDateString()
  dateFin?: string;

  @ApiPropertyOptional({ description: 'UUID du responsable (défaut : le créateur)' })
  @IsOptional()
  @IsUUID()
  assignedToId?: string;
}

export class UpdateOpportuniteDto {
  @ApiPropertyOptional({ enum: StatutOpportunite, description: 'Faire évoluer le statut' })
  @IsOptional()
  @IsEnum(StatutOpportunite)
  statut?: StatutOpportunite;

  @ApiPropertyOptional({ type: [String], description: 'Remplace la liste des articles visés' })
  @IsOptional()
  @IsArray()
  @IsUUID(undefined, { each: true })
  articleIds?: string[];

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) libelle?: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) valeurEstimee?: number;
  @ApiPropertyOptional() @IsOptional() @IsDateString() dateDebut?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() dateFin?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() assignedToId?: string;
}

export class QueryOpportunitesDto {
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

  @ApiPropertyOptional({ enum: TypeOpportunite })
  @IsOptional()
  @IsEnum(TypeOpportunite)
  type?: TypeOpportunite;

  @ApiPropertyOptional({ enum: StatutOpportunite })
  @IsOptional()
  @IsEnum(StatutOpportunite)
  statut?: StatutOpportunite;

  @ApiPropertyOptional({ description: 'Opportunités d’un prospect (UUID)' })
  @IsOptional()
  @IsUUID()
  prospectId?: string;

  @ApiPropertyOptional({ description: 'Opportunités d’un client (UUID)' })
  @IsOptional()
  @IsUUID()
  clientId?: string;
}
