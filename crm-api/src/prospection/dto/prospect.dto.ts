import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MotifPerteProspect, NiveauClass, PipelineEtape, ResultatAppel, SourceProspect } from '@crm/database';

export class CreateProspectDto {
  @ApiProperty({ example: 'SUPERMARCHE DUPONT SAS' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  raisonSociale!: string;

  @ApiProperty({ example: 'Carrefour Contact Lunel' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  enseigne!: string;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) adresse1?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) codePostal?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) ville?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) telephone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) email?: string;

  @ApiPropertyOptional({ description: 'UUID du secteur (territoire, base du scoping)' })
  @IsOptional()
  @IsUUID()
  secteurId?: string;

  @ApiPropertyOptional({ description: 'UUID du chef de secteur responsable (défaut : le créateur)' })
  @IsOptional()
  @IsUUID()
  assignedToId?: string;

  @ApiPropertyOptional({ enum: PipelineEtape, default: PipelineEtape.NOUVEAU })
  @IsOptional()
  @IsEnum(PipelineEtape)
  statut?: PipelineEtape;

  @ApiPropertyOptional({ description: 'Probabilité en % (défaut selon l’étape du pipeline)' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  probabilite?: number;

  @ApiPropertyOptional({ description: 'CA annuel estimé (€)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  potentielCaAnnuel?: number;

  @ApiPropertyOptional({ enum: SourceProspect })
  @IsOptional()
  @IsEnum(SourceProspect)
  source?: SourceProspect;

  @ApiPropertyOptional({ enum: NiveauClass, description: 'Classe estimée du magasin (A++ à venir — A à G aujourd’hui), saisie à la création de la fiche' })
  @IsOptional()
  @IsEnum(NiveauClass)
  niveauClass?: NiveauClass;
}

export class CreateProspectApkDto extends CreateProspectDto {
  @ApiProperty({ description: "Identifiant généré côté mobile — clé d'idempotence de la sync offline" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  idApk!: string;
}

export class UpdateProspectDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @IsNotEmpty() @MaxLength(200) raisonSociale?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @IsNotEmpty() @MaxLength(200) enseigne?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) adresse1?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(10) codePostal?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(100) ville?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(20) telephone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(200) email?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() secteurId?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() assignedToId?: string;

  @ApiPropertyOptional({
    enum: PipelineEtape,
    description: "Faire avancer l'étape — la probabilité par défaut de l'étape s'applique si elle n'est pas fournie",
  })
  @IsOptional()
  @IsEnum(PipelineEtape)
  statut?: PipelineEtape;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) probabilite?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) potentielCaAnnuel?: number;

  @ApiPropertyOptional({ enum: SourceProspect })
  @IsOptional()
  @IsEnum(SourceProspect)
  source?: SourceProspect;

  @ApiPropertyOptional({ enum: MotifPerteProspect, description: 'À renseigner quand statut = PERDU' })
  @IsOptional()
  @IsEnum(MotifPerteProspect)
  motifPerte?: MotifPerteProspect;
}

export class QueryProspectsDto {
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

  @ApiPropertyOptional({ description: 'Recherche sur enseigne / raison sociale / ville' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filtrer par secteur (UUID)' })
  @IsOptional()
  @IsUUID()
  secteur?: string;

  @ApiPropertyOptional({ enum: PipelineEtape, description: 'Filtrer par étape du pipeline' })
  @IsOptional()
  @IsEnum(PipelineEtape)
  statut?: PipelineEtape;

  @ApiPropertyOptional({ description: 'Filtrer par responsable (UUID utilisateur)' })
  @IsOptional()
  @IsUUID()
  assignedTo?: string;
}


/** Appel téléphonique passé à un prospect (app mobile — idApk pour l'idempotence). */
export class CreateAppelDto {
  @ApiPropertyOptional({ description: "Horodatage de l'appel (défaut : maintenant)" })
  @IsOptional()
  @IsDateString()
  dateAppel?: string;

  @ApiPropertyOptional({ description: "Durée de l'appel en secondes" })
  @IsOptional()
  @IsInt()
  @Min(0)
  dureeSec?: number;

  @ApiPropertyOptional({ enum: ResultatAppel, default: ResultatAppel.REPONDU })
  @IsOptional()
  @IsEnum(ResultatAppel)
  resultat?: ResultatAppel;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({ description: 'Clé d’idempotence générée côté mobile' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}


/** Email envoyé à un prospect (fiche Helios ou app mobile — idApk pour l'idempotence). */
export class CreateEmailDto {
  @ApiPropertyOptional({ description: "Horodatage de l'envoi (défaut : maintenant)" })
  @IsOptional()
  @IsDateString()
  dateEmail?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  destinataire?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  sujet?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({ description: 'Clé d’idempotence générée côté mobile' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

/** Note libre ajoutée à la fiche prospect (Helios). */
export class CreateNoteProspectDto {
  @ApiProperty({ example: 'Point avec le directeur : relancer après les fêtes.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  remarque!: string;
}
