import { BadRequestException, Res, UploadedFile, UseInterceptors,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ProspectsService } from './prospects.service';
import {
  CreateAppelDto,
  CreateEmailDto,
  CreateNoteProspectDto,
  CreateProspectApkDto,
  CreateProspectDto,
  QueryProspectsDto,
  UpdateProspectDto,
} from './dto/prospect.dto';

/**
 * Prospection & pipeline (module Helios).
 * Matrice de rôles : CS = secteur, DR = région, Direction = lecture globale,
 * ADMIN = tout. Détail par route via @Roles + scoping dans le service.
 */
@ApiTags('prospection')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('prospects')
export class ProspectsController {
  constructor(private readonly prospects: ProspectsService) {}

  @Get()
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({
    summary:
      'Liste paginée des prospects (search, secteur, statut, assignedTo) — scopée : CS = ses secteurs, DR = sa région, Direction/ADMIN = tout',
  })
  findAll(@Query() query: QueryProspectsDto, @CurrentUser() user: User) {
    return this.prospects.findAll(user, query);
  }

  @Get('pipeline')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({
    summary:
      'Pipeline : prospects groupés par étape (vue Kanban), avec total et valeur pondérée (CA potentiel × probabilité) par colonne',
  })
  pipeline(@CurrentUser() user: User) {
    return this.prospects.pipeline(user);
  }

  @Post()
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({ summary: 'Créer un prospect (CS · DR) — assigné au créateur par défaut' })
  create(@Body() dto: CreateProspectDto, @CurrentUser() user: User) {
    return this.prospects.create(user, dto);
  }

  @Post('apk')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({
    summary:
      "Créer un prospect depuis le mobile (offline) — idempotent par idApk : l'outbox peut rejouer sans doublon",
  })
  createApk(@Body() dto: CreateProspectApkDto, @CurrentUser() user: User) {
    return this.prospects.createApk(user, dto);
  }

  @Get(':id')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({ summary: 'Fiche prospect (coordonnées, contacts, notes) — 404 hors périmètre' })
  findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.prospects.findOne(user, id);
  }

  @Get(':id/pieces-jointes')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @ApiOperation({ summary: 'Pièces jointes de la fiche prospect' })
  listPiecesJointes(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.prospects.listPiecesJointes(user, id);
  }

  @Post(':id/pieces-jointes')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @UseInterceptors(FileInterceptor('fichier'))
  @ApiOperation({ summary: 'Déposer une pièce jointe (multipart, champ « fichier », 10 Mo max)' })
  addPieceJointe(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() fichier: { originalname: string; mimetype: string; size: number; buffer: Buffer },
    @CurrentUser() user: User,
  ) {
    if (!fichier) throw new BadRequestException('Aucun fichier reçu (champ « fichier »).');
    return this.prospects.addPieceJointe(user, id, fichier);
  }

  @Get(':id/pieces-jointes/:pjId')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @ApiOperation({ summary: 'Télécharger une pièce jointe' })
  async getPieceJointe(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('pjId', ParseUUIDPipe) pjId: string,
    @CurrentUser() user: User,
    @Res() res: Response,
  ) {
    const pj = await this.prospects.getPieceJointe(user, id, pjId);
    res.setHeader('Content-Type', pj.mime);
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(pj.nom)}"`);
    res.send(Buffer.from(pj.donnees));
  }

  @Delete(':id/pieces-jointes/:pjId')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer (logiquement) une pièce jointe' })
  removePieceJointe(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('pjId', ParseUUIDPipe) pjId: string,
    @CurrentUser() user: User,
  ) {
    return this.prospects.removePieceJointe(user, id, pjId);
  }

  @Post(':id/notes')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @ApiOperation({ summary: 'Ajouter une note à la fiche prospect (timeline)' })
  addNote(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateNoteProspectDto,
    @CurrentUser() user: User,
  ) {
    return this.prospects.addNote(user, id, dto.remarque);
  }

  @Post(':id/appels')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @ApiOperation({
    summary: "Journalise un appel téléphonique passé au prospect (app mobile) — idempotent par idApk",
  })
  createAppel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateAppelDto,
    @CurrentUser() user: User,
  ) {
    return this.prospects.createAppel(user, id, dto);
  }

  @Post(':id/emails')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN, Role.COMMERCIAL)
  @ApiOperation({ summary: "Journalise un email envoyé au prospect — idempotent par idApk" })
  createEmail(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateEmailDto,
    @CurrentUser() user: User,
  ) {
    return this.prospects.createEmail(user, id, dto);
  }

  @Get(':id/historique')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({ summary: 'Timeline du prospect : visites de prospection et opportunités, antéchronologique' })
  historique(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.prospects.historique(user, id);
  }

  @Patch(':id')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({
    summary:
      "Éditer / faire avancer l'étape — un changement d'étape applique la probabilité par défaut (sauf fournie) ; motifPerte requis pour PERDU",
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProspectDto,
    @CurrentUser() user: User,
  ) {
    return this.prospects.update(user, id, dto);
  }

  @Delete(':id')
  @Roles(Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer un prospect (soft delete) — DR · ADMIN' })
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.prospects.remove(user, id);
  }

  @Post(':id/convert')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({
    summary:
      'Convertir en client (idempotent) : crée le Client depuis le prospect (codeAs400 provisoire PRSP-xxxxxxxx), y rattache contacts/notes/visites/opportunités, statut → GAGNE',
  })
  convert(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    return this.prospects.convert(user, id);
  }
}
