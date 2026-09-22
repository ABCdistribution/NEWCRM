import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { NiveauClass } from '@crm/database';
import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateClientDto {
  @ApiProperty({ example: '0042315', description: 'Code ERP (AS/400), unique' })
  @IsString()
  @IsNotEmpty()
  codeAs400!: string;

  @ApiProperty({ example: 'ABC Market' })
  @IsString()
  @IsNotEmpty()
  enseigne!: string;

  @ApiProperty({ example: 'ABC Market SARL' })
  @IsString()
  @IsNotEmpty()
  raisonSociale!: string;

  // --- Adresse (éclatée comme dans Minos) ---
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adresse1?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adresse2?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  adresse3?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  codePostal?: string;

  @ApiPropertyOptional({ description: 'CP scindé en 2 par Minos' })
  @IsOptional()
  @IsString()
  codePostal2?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  ville?: string;

  @ApiPropertyOptional({ default: 'France' })
  @IsOptional()
  @IsString()
  pays?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  langue?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  devise?: string;

  // --- Identité / contacts ---
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  siret?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  eanClient?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  tel1?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  tel2?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contact1?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contact2?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contact3?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;

  // --- Champs CRM / statuts ---
  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  actif?: boolean;

  @ApiPropertyOptional({ enum: NiveauClass, description: 'Note CRM A→G' })
  @IsOptional()
  @IsEnum(NiveauClass)
  niveauClass?: NiveauClass;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  statutCommande?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  statutLivre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  statutFacture?: string;

  // --- Relations ---
  @ApiPropertyOptional({ description: 'UUID du secteur de rattachement' })
  @IsOptional()
  @IsUUID()
  secteurId?: string;

  @ApiPropertyOptional({ description: 'UUID du créateur (client saisi manuellement)' })
  @IsOptional()
  @IsUUID()
  creeParId?: string;
}
