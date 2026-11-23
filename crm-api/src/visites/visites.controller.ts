import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { lireModifieDepuis, ModifieDepuisQuery } from '../common/modifie-depuis';
import { auteursDeVisitesVisibles, ETAPES_PHOTO, ETAPES_VISITE, VisitesService } from './visites.service';

const rognerChaine = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

class ReponseDto {
  @ApiProperty({ description: 'UUID de la question du questionnaire' })
  @IsUUID()
  questionId!: string;

  @ApiProperty({ description: 'Valeur sérialisée selon le type (true/false, texte, nombre, note 1-5)' })
  @IsString()
  @MaxLength(2000)
  valeur!: string;
}

class KitDto {
  @ApiProperty({ example: 'KIT91265', description: 'Code du kit constaté en rayon' })
  @Transform(rognerChaine)
  @IsString({ message: 'Le code du kit doit être un texte' })
  @MinLength(1, { message: 'Le code du kit est obligatoire' })
  @MaxLength(64, { message: 'Le code du kit ne doit pas dépasser 64 caractères' })
  code!: string;

  @ApiProperty({ example: 5, description: 'Nombre de références du kit constatées en rayon' })
  @IsInt({ message: 'Le nombre de références doit être un entier' })
  @Min(0, { message: 'Le nombre de références ne peut pas être négatif' })
  @Max(1000, { message: 'Le nombre de références ne doit pas dépasser 1000' })
  references!: number;
}

class PromoOpDto {
  @ApiProperty({ description: 'UUID de la promotion pointée' })
  @IsUUID(undefined, { message: "promoId doit être l'identifiant d'une promotion" })
  promoId!: string;

  @ApiProperty({ description: 'Promotion en place en rayon ?' })
  @IsBoolean({ message: 'presente doit être vrai ou faux' })
  presente!: boolean;
}

class IndispensableDto {
  @ApiProperty({ description: "UUID de l'article indispensable relevé" })
  @IsUUID(undefined, { message: "articleId doit être l'identifiant d'un article" })
  articleId!: string;

  @ApiProperty({ description: 'Produit présent en rayon ?' })
  @IsBoolean({ message: 'present doit être vrai ou faux' })
  present!: boolean;
}

class ArticlePemDto {
  @ApiProperty({ description: "UUID de l'article PEM vérifié" })
  @IsUUID(undefined, { message: "articleId doit être l'identifiant d'un article" })
  articleId!: string;

  @ApiProperty({ description: 'Article présent en rayon ?' })
  @IsBoolean({ message: 'present doit être vrai ou faux' })
  present!: boolean;

  @ApiProperty({ description: 'Article mis en avant ? (ignoré, donc faux, si l’article est absent)' })
  @IsBoolean({ message: 'misEnAvant doit être vrai ou faux' })
  misEnAvant!: boolean;
}

class EtapeDto {
  @ApiProperty({ enum: ETAPES_VISITE })
  @IsIn(ETAPES_VISITE, { message: `etape doit être l'une des valeurs : ${ETAPES_VISITE.join(', ')}` })
  etape!: string;

  @ApiProperty({ example: '2026-11-18T08:30:00.000Z', description: "Date et heure ISO 8601 de l'étape" })
  @IsISO8601({ strict: true }, { message: 'horodatage doit être une date ISO 8601 (ex. 2026-11-18T08:30:00Z)' })
  horodatage!: string;
}

class CreateVisiteDto {
  @ApiProperty({ description: 'Identifiant généré côté mobile (clé d’idempotence de la sync)' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  idApk!: string;

  @ApiPropertyOptional({
    description: 'UUID du magasin visité — exactement un de clientId / prospectId',
  })
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @ApiPropertyOptional({
    description: 'UUID du prospect visité (visite de prospection) — exactement un de clientId / prospectId',
  })
  @IsOptional()
  @IsUUID()
  prospectId?: string;

  @ApiPropertyOptional({ description: 'Visite planifiée soldée par ce compte-rendu' })
  @IsOptional()
  @IsUUID()
  planningId?: string;

  @ApiPropertyOptional({ example: 'Planifiée', description: 'Planifiée · Appel client · Passage opportunité · Urgence · Prospection…' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  motif?: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnAbc?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnConcurrence?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnGondoleHaute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnGondoleBasse?: number;

  @ApiPropertyOptional({ description: 'Commentaire libre' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({
    description: "Commande prise pendant la visite (idCommandeApk de la commande mobile) — exclusif avec raisonAbsenceCommandeId",
  })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z0-9]{4,10}$/, { message: 'idCommandeApk doit contenir 4 à 10 caractères alphanumériques' })
  idCommandeApk?: string;

  @ApiPropertyOptional({
    description: "UUID de la raison d'absence de commande — exclusif avec idCommandeApk",
  })
  @IsOptional()
  @IsUUID()
  raisonAbsenceCommandeId?: string;

  @ApiPropertyOptional({ type: [ReponseDto], description: 'Réponses au questionnaire de fin de visite' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ReponseDto)
  reponses?: ReponseDto[];

  @ApiPropertyOptional({ description: 'Étape « commande à mettre en rayon ? » — absent ou null = pas répondu' })
  @IsOptional()
  @IsBoolean({ message: 'commandeEnRayon doit être vrai ou faux' })
  commandeEnRayon?: boolean;

  @ApiPropertyOptional({ type: [String], description: 'Codes de colis scannés / saisis (1 à 64 caractères, 200 max, dédoublonnés)' })
  @IsOptional()
  @IsArray({ message: 'colis doit être une liste' })
  @ArrayMaxSize(200, { message: 'Pas plus de 200 colis par visite' })
  @Transform(({ value }) => (Array.isArray(value) ? value.map((v) => rognerChaine({ value: v })) : value))
  @IsString({ each: true, message: 'Chaque code de colis doit être un texte' })
  @MinLength(1, { each: true, message: 'Un code de colis ne peut pas être vide' })
  @MaxLength(64, { each: true, message: 'Un code de colis ne doit pas dépasser 64 caractères' })
  colis?: string[];

  @ApiPropertyOptional({ type: [KitDto], description: 'Kits constatés en rayon (vérification DN) : code et nombre de références' })
  @IsOptional()
  @IsArray({ message: 'kits doit être une liste' })
  @ArrayMaxSize(100, { message: 'Pas plus de 100 kits par visite' })
  @ValidateNested({ each: true })
  @Type(() => KitDto)
  kits?: KitDto[];

  @ApiPropertyOptional({ type: [PromoOpDto], description: 'Pointage OP : promotion et présence en rayon' })
  @IsOptional()
  @IsArray({ message: 'promosOp doit être une liste' })
  @ArrayMaxSize(200, { message: 'Pas plus de 200 promotions pointées par visite' })
  @ValidateNested({ each: true })
  @Type(() => PromoOpDto)
  promosOp?: PromoOpDto[];

  @ApiPropertyOptional({ type: [IndispensableDto], description: 'Produits indispensables : article et présence en rayon (dédoublonnés par article, dernier gagnant)' })
  @IsOptional()
  @IsArray({ message: 'indispensables doit être une liste' })
  @ArrayMaxSize(200, { message: 'Pas plus de 200 produits indispensables par visite' })
  @ValidateNested({ each: true })
  @Type(() => IndispensableDto)
  indispensables?: IndispensableDto[];

  @ApiPropertyOptional({ enum: ['COMMERCIALE', 'PEM'], description: 'Nature de la visite (défaut COMMERCIALE ; PEM si propositionPemId est fourni)' })
  @IsOptional()
  @IsIn(['COMMERCIALE', 'PEM'], { message: 'typeVisite doit être COMMERCIALE ou PEM' })
  typeVisite?: 'COMMERCIALE' | 'PEM';

  @ApiPropertyOptional({ description: 'Visite PEM : proposition réalisée par cette visite (passe à REALISEE, compteur de reports remis à zéro)' })
  @IsOptional()
  @IsUUID(undefined, { message: "propositionPemId doit être l'identifiant d'une proposition PEM" })
  propositionPemId?: string;

  @ApiPropertyOptional({ type: [ArticlePemDto], description: 'Visite PEM : articles PEM vérifiés (présent / absent, mis en avant), dédoublonnés par article' })
  @IsOptional()
  @IsArray({ message: 'articlesPem doit être une liste' })
  @ArrayMaxSize(200, { message: 'Pas plus de 200 articles PEM par visite' })
  @ValidateNested({ each: true })
  @Type(() => ArticlePemDto)
  articlesPem?: ArticlePemDto[];

  @ApiPropertyOptional({ type: [EtapeDto], description: 'Chrono : horodatage de chaque étape faite' })
  @IsOptional()
  @IsArray({ message: 'etapes doit être une liste' })
  @ArrayMaxSize(20, { message: 'Pas plus de 20 étapes par visite' })
  @ValidateNested({ each: true })
  @Type(() => EtapeDto)
  etapes?: EtapeDto[];
}

class PhotoDto {
  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile (rejeu de l'outbox sans doublon)" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;

  @ApiPropertyOptional({ enum: ETAPES_PHOTO, description: 'Étape du parcours à laquelle appartient la photo' })
  @IsOptional()
  @IsIn(ETAPES_PHOTO, { message: `etape doit être l'une des valeurs : ${ETAPES_PHOTO.join(', ')}` })
  etape?: string;
}

@ApiTags('visites')
@ApiBearerAuth()
// Pas d'accès pour le marketing (ni liste, ni création, ni photos).
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(...ROLES_COMMANDES_VISITES)
@Controller('visites')
export class VisitesController {
  constructor(private readonly visites: VisitesService) {}

  @Get()
  @ApiOperation({
    summary:
      'Visites paginées — un commercial voit les siennes, un CS / DR celles de son équipe, les autres rôles toutes ; ?tous=1 lève la restriction (bascule « Mes visites / Toutes »)',
  })
  findAll(
    @Query('page') page: string | undefined,
    @Query('search') search: string | undefined,
    @Query('tous') tous: string | undefined,
    @Query('dateDepuis') dateDepuis: string | undefined,
    @Query() { modifieDepuis }: ModifieDepuisQuery,
    @CurrentUser() me: User,
  ) {
    // tous=1 : bascule « Mes visites / Toutes » — lève la restriction du promoteur (ses visites) et du chef de secteur /
    // directeur régional (leur équipe). Sans elle, le comportement est celui de toujours.
    const lever = tous === '1';
    const promoteurId = me.role === 'COMMERCIAL' && !lever ? me.id : null;
    const equipe = !lever && (me.role === 'CHEF_SECTEUR' || me.role === 'DIRECTEUR_REGIONAL') ? auteursDeVisitesVisibles(me) : null;
    return this.visites.findAll(promoteurId, {
      page: Number(page) || 1,
      search,
      equipe: equipe ?? undefined,
      modifieDepuis: lireModifieDepuis(modifieDepuis),
      dateDepuis: dateDepuis && !Number.isNaN(new Date(dateDepuis).getTime()) ? new Date(dateDepuis) : undefined,
    });
  }

  @Post()
  @ApiOperation({
    summary:
      "Compte-rendu de visite (app mobile) : parcours (colis, kits DN, pointage OP, chrono), questionnaire, motif — idempotent par idApk, solde la visite planifiée liée",
  })
  create(@Body() dto: CreateVisiteDto, @CurrentUser() me: User) {
    return this.visites.create(me, dto);
  }

  @Post(':id/photos')
  @UseInterceptors(FileInterceptor('photo', { limits: { fileSize: 10 * 1024 * 1024 } }))
  @ApiOperation({
    summary: 'Photo de rayon attachée à une visite (multipart, champs « photo », « idApk », « etape » ; 10 Mo max) — idempotent par idApk',
  })
  addPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() photo: { originalname: string; mimetype: string; size: number; buffer: Buffer } | undefined,
    @Body() dto: PhotoDto,
    @CurrentUser() me: User,
  ) {
    if (!photo) throw new BadRequestException('Aucune photo reçue (champ « photo »).');
    return this.visites.addPhoto(me, id, photo, dto.idApk, dto.etape);
  }

  @Get(':id/photos')
  @ApiOperation({ summary: "Photos d'une visite (métadonnées)" })
  listPhotos(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    return this.visites.listPhotos(me, id);
  }

  @Get(':id/photos/:photoId')
  @ApiOperation({ summary: "Télécharger une photo de visite" })
  async getPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentUser() me: User,
    @Res() res: Response,
  ) {
    const p = await this.visites.getPhoto(me, id, photoId);
    res.setHeader('Content-Type', p.mime);
    res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(p.nom)}"`);
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(Buffer.from(p.donnees));
  }
}
