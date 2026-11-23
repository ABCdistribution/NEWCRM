import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { NiveauClass, Role, StatutPropositionPem, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { ModifieDepuisQuery } from '../common/modifie-depuis';
import { PemService } from './pem.service';

const rognerChaine = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const FORMAT_JOUR = /^\d{4}-\d{2}-\d{2}$/;

/** Rôles qui consultent les propositions : promoteurs, encadrement et direction (ni ADV ni marketing). */
const ROLES_PROPOSITIONS = [Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR, Role.COMMERCIAL] as const;

class FrequenceClasseDto {
  @ApiProperty({ enum: NiveauClass })
  @IsEnum(NiveauClass, { message: 'niveauClass doit être une classe de A à G' })
  niveauClass!: NiveauClass;

  @ApiProperty({ example: 4, description: 'Fréquence des visites PEM, en semaines (1 à 52)' })
  @IsInt({ message: 'semaines doit être un entier' })
  @Min(1, { message: 'La fréquence doit être d’au moins 1 semaine' })
  @Max(52, { message: 'La fréquence ne doit pas dépasser 52 semaines' })
  semaines!: number;
}

class MajFrequencesDto {
  @ApiProperty({ type: [FrequenceClasseDto] })
  @IsArray({ message: 'classes doit être une liste' })
  @ArrayMinSize(1, { message: 'Indiquer au moins une classe' })
  @ArrayMaxSize(7, { message: 'Il n’y a que 7 classes (A à G)' })
  @ValidateNested({ each: true })
  @Type(() => FrequenceClasseDto)
  classes!: FrequenceClasseDto[];
}

class QueryPropositionsDto extends ModifieDepuisQuery {
  @ApiPropertyOptional({ enum: StatutPropositionPem, description: 'Sans statut : propositions ouvertes (PROPOSEE, ACCEPTEE)' })
  @IsOptional()
  @IsEnum(StatutPropositionPem, { message: `statut doit être l'une des valeurs : ${Object.values(StatutPropositionPem).join(', ')}` })
  statut?: StatutPropositionPem;

  @ApiPropertyOptional({ description: 'Ne renvoyer que les propositions de ce magasin (dans le périmètre de l\'appelant)' })
  @IsOptional()
  @IsUUID(undefined, { message: "clientId doit être l'identifiant d'un magasin" })
  clientId?: string;

  @ApiPropertyOptional({ description: 'Page (200 lignes par page)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'page doit être un entier' })
  @Min(1, { message: 'page doit être supérieure ou égale à 1' })
  page?: number;
}

class AccepterDto {
  @ApiPropertyOptional({ example: '2026-12-02', description: "Date de la visite (AAAA-MM-JJ), d'aujourd'hui à +14 jours ; défaut : la date proposée" })
  @IsOptional()
  @Matches(FORMAT_JOUR, { message: 'date doit être au format AAAA-MM-JJ' })
  date?: string;
}

class ReporterDto {
  @ApiPropertyOptional({ description: 'Motif du refus ou du report' })
  @IsOptional()
  @Transform(rognerChaine)
  @IsString({ message: 'Le motif doit être un texte' })
  @MaxLength(500, { message: 'Le motif ne doit pas dépasser 500 caractères' })
  motif?: string;

  @ApiPropertyOptional({ example: '2026-12-09', description: 'Nouvelle date (AAAA-MM-JJ), de demain à +14 jours ; défaut : dans 7 jours (jour ouvré)' })
  @IsOptional()
  @Matches(FORMAT_JOUR, { message: 'date doit être au format AAAA-MM-JJ' })
  date?: string;
}

class SuiviPemDto {
  @ApiProperty({ description: 'Magasin soumis au suivi PEM ?' })
  @IsBoolean({ message: 'suiviPem doit être vrai ou faux' })
  suiviPem!: boolean;
}

/** Visites PEM : fréquences, articles, propositions (acceptation / report) et programmation. */
@ApiTags('pem')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('pem')
export class PemController {
  constructor(private readonly pem: PemService) {}

  @Get('frequences')
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: 'Fréquence des visites PEM (en semaines) par classe de magasin A à G' })
  frequences() {
    return this.pem.frequences();
  }

  @Put('frequences')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Modifier la fréquence des visites PEM pour une ou plusieurs classes' })
  majFrequences(@Body() dto: MajFrequencesDto) {
    return this.pem.majFrequences(dto.classes);
  }

  @Get('articles')
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: 'Articles PEM actifs à vérifier pendant une visite PEM (présent / absent, mis en avant)' })
  articles() {
    return this.pem.articles();
  }

  @Get('propositions')
  @Roles(...ROLES_PROPOSITIONS)
  @ApiOperation({
    summary:
      'Propositions de visite PEM — un promoteur voit les siennes, un chef de secteur / directeur régional celles de son équipe, ADMIN / DIRECTION toutes',
  })
  propositions(@Query() query: QueryPropositionsDto, @CurrentUser() me: User) {
    return this.pem.propositions(me, { statut: query.statut, modifieDepuis: query.modifieDepuis, page: query.page, clientId: query.clientId });
  }

  @Post('propositions/:id/accepter')
  @Roles(Role.COMMERCIAL)
  @ApiOperation({ summary: 'Le promoteur accepte la visite PEM : ajout au planning (idempotent)' })
  accepter(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AccepterDto, @CurrentUser() me: User) {
    return this.pem.accepter(me, id, dto.date);
  }

  @Post('propositions/:id/reporter')
  @Roles(Role.COMMERCIAL)
  @ApiOperation({ summary: 'Le promoteur refuse ou reporte la visite PEM (3 reports : visite obligatoire, puis 409)' })
  reporter(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ReporterDto, @CurrentUser() me: User) {
    return this.pem.reporter(me, id, dto.motif, dto.date);
  }

  @Post('programmer')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Déclenche la programmation PEM (normalement quotidienne) : nombre de propositions créées' })
  programmer() {
    return this.pem.programmer();
  }
}

/** Indicateur « soumis au suivi PEM » de la fiche client (route sous /clients, logique dans le module PEM). */
@ApiTags('clients')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('clients')
export class PemClientsController {
  constructor(private readonly pem: PemService) {}

  @Patch(':id/suivi-pem')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL)
  @ApiOperation({
    summary:
      'Active / désactive le suivi PEM du magasin (directeur régional : sa région seulement). Activer programme aussitôt la visite PEM ; désactiver annule la proposition ouverte.',
  })
  suiviPem(@Param('id', ParseUUIDPipe) id: string, @Body() dto: SuiviPemDto, @CurrentUser() me: User) {
    return this.pem.changerSuivi(me, id, dto.suiviPem);
  }
}
