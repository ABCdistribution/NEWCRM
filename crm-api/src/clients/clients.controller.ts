import {
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
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsDateString, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength, Min, ValidateIf } from 'class-validator';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PLANIFICATEURS, ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ClientsService } from './clients.service';
import { CreateClientDto } from './dto/create-client.dto';
import { UpdateClientDto } from './dto/update-client.dto';
import { QueryClientsDto } from './dto/query-clients.dto';
import { CreateContactDto, UpdateContactDto } from './dto/contact.dto';

/** Appelant tel que posé par JwtAuthGuard, avec de quoi calculer son périmètre de magasins. */
type UtilisateurPerimetre = { id: string; role: string; idRepr: string | null; regionId: string | null };

/**
 * Rôles qui journalisent l'activité terrain d'un magasin (visite commerciale, appel, e-mail) : l'encadrement et le
 * promoteur (COMMERCIAL). Ni le marketing (pas d'accès aux visites), ni l'ADV (aucune action terrain dans le front).
 * Le périmètre (magasins du promoteur / du secteur / de la région) est ensuite vérifié par le service.
 */
const ROLES_ACTIVITE_TERRAIN = [...PLANIFICATEURS, Role.COMMERCIAL] as const;

class CreateNoteDto {
  @ApiProperty({ example: 'Rayon DPH réagencé, prévoir PLV en septembre.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  remarque!: string;

  @ApiPropertyOptional({ description: "Identifiant généré côté mobile (clé d'idempotence de la sync)" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

class ReponseVisiteDto {
  @ApiProperty({ example: 'Validation assortiment' })
  @IsString()
  @IsNotEmpty()
  libelle!: string;

  @ApiProperty()
  ok!: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  remarque?: string;
}

class CreateVisiteCommercialeDto {
  @ApiPropertyOptional()
  @IsOptional()
  avecRdv?: boolean;

  @ApiPropertyOptional({ type: [String], example: ['Bilan activité', 'Dynamique promotionnelle'] })
  @IsOptional()
  objets?: string[];

  @ApiPropertyOptional({ description: 'Remplissage du linéaire', example: 'Moitié' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  remplissage?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  compteRendu?: string;

  @ApiPropertyOptional({ description: 'Date de prochaine visite (YYYY-MM-DD)' })
  @IsOptional()
  @IsString()
  prochaineVisite?: string;

  @ApiPropertyOptional({ type: [ReponseVisiteDto] })
  @IsOptional()
  reponses?: ReponseVisiteDto[];

  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile (rejeu de l'outbox sans doublon)" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;

  @ApiPropertyOptional({ description: 'Début de la visite (ISO) — horodatage VisiteStep DEBUT_VISITE_CS' })
  @IsOptional()
  @IsDateString()
  debut?: string;

  @ApiPropertyOptional({ description: 'Fin de la visite (ISO, défaut : maintenant) — horodatage VisiteStep FIN_VISITE_CS' })
  @IsOptional()
  @IsDateString()
  fin?: string;
}

class CreateAppelClientDto {
  @ApiPropertyOptional({ description: "Date de l'appel (défaut : maintenant)" })
  @IsOptional()
  @IsString()
  dateAppel?: string;

  @ApiPropertyOptional({ enum: ['REPONDU', 'SANS_REPONSE', 'MESSAGERIE', 'RAPPEL_PREVU'] })
  @IsOptional()
  @IsIn(['REPONDU', 'SANS_REPONSE', 'MESSAGERIE', 'RAPPEL_PREVU'])
  resultat?: 'REPONDU' | 'SANS_REPONSE' | 'MESSAGERIE' | 'RAPPEL_PREVU';

  @ApiPropertyOptional({ description: "Durée de l'appel en secondes (journal d'appels du téléphone)" })
  @IsOptional()
  @IsInt()
  @Min(0)
  dureeSec?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

class CreateEmailClientDto {
  @ApiPropertyOptional({ description: "Date de l'email (défaut : maintenant)" })
  @IsOptional()
  @IsString()
  dateEmail?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(320)
  destinataire?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  sujet?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

class SetPeriodiciteDto {
  @ApiPropertyOptional({ description: 'UUID de la périodicité (null = aucune)', nullable: true })
  @IsOptional()
  @ValidateIf((o: SetPeriodiciteDto) => o.periodiciteId !== null)
  @IsUUID()
  periodiciteId?: string | null;
}

@ApiTags('clients')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('clients')
export class ClientsController {
  constructor(private readonly clients: ClientsService) {}

  @Get()
  @ApiOperation({
    summary:
      'Liste paginée des clients (recherche via ?search=). Un commercial relié à un code représentant ne voit que ses magasins.',
  })
  findAll(
    @Query() query: QueryClientsDto,
    @CurrentUser() user: { id: string; role: string; idRepr: string | null; regionId: string | null },
  ) {
    return this.clients.findAll(query, user);
  }

  // Déclarée avant GET :id pour ne pas être happée par le ParseUUIDPipe.
  @Get('passes-inactifs')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR, Role.ADV)
  @ApiOperation({
    summary:
      "Clients passés inactifs sur un mois (?mois=AAAA-MM) : enseigne, code, ville, date, auteur, DR, envoi à l'ADV. Historique pas encore enregistré : renvoie disponible=false",
  })
  passesInactifs(@Query('mois') mois?: string) {
    return this.clients.passesInactifs(mois);
  }

  // Déclarée avant GET :id pour ne pas être happée par le ParseUUIDPipe.
  @Get('geo')
  @ApiOperation({
    summary:
      'Points de vente géolocalisables (carte du secteur) — scopés : CS = ses promoteurs, DR = sa région, direction = tout',
  })
  geo(@CurrentUser() user: { id: string; role: string; idRepr: string | null; regionId: string | null }) {
    return this.clients.findGeo(user);
  }

  // Déclarée avant GET :id pour ne pas être happée par le ParseUUIDPipe.
  @Get('fiches')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({
    summary:
      'Contacts et notes des magasins du périmètre de l\'appelant en un appel (réplication mobile hors ligne) — promoteur = ses magasins, CS = ses promoteurs, DR = sa région',
  })
  fiches(@CurrentUser() user: UtilisateurPerimetre) {
    return this.clients.findFiches(user);
  }

  @Get(':id')
  @ApiOperation({ summary: "Détail d'un client (limité au périmètre de l'appelant : hors périmètre = 404)" })
  async findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: { id: string; role: string; idRepr: string | null; regionId: string | null },
  ) {
    const detail = await this.clients.findOneDetail(id, user);
    // Le marketing ne voit ni commandes ni visites : pas non plus leurs compteurs.
    if (user.role === Role.MARKETING) {
      const { _count, ...reste } = detail as typeof detail & { _count?: unknown };
      void _count;
      return reste;
    }
    return detail;
  }

  @Get(':id/historique')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES) // contient des commandes et des visites : pas d'accès pour le marketing
  @ApiOperation({ summary: 'Historique du magasin : commandes, visites, CA mensuel N / N-1 (pas de marketing)' })
  historique(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: UtilisateurPerimetre) {
    return this.clients.findHistorique(id, user);
  }

  @Post(':id/contacts')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Ajouter un contact au magasin (limité au périmètre de l'appelant : hors périmètre = 404)" })
  addContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateContactDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.addContact(id, dto, user);
  }

  @Patch(':id/contacts/:contactId')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Modifier un contact du magasin (limité au périmètre de l'appelant : hors périmètre = 404)" })
  updateContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('contactId', ParseUUIDPipe) contactId: string,
    @Body() dto: UpdateContactDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.updateContact(id, contactId, dto, user);
  }

  @Delete(':id/contacts/:contactId')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Supprimer (logiquement) un contact du magasin (limité au périmètre : hors périmètre = 404)" })
  removeContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('contactId', ParseUUIDPipe) contactId: string,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.removeContact(id, contactId, user);
  }

  @Post(':id/visites-commerciales')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_ACTIVITE_TERRAIN)
  @ApiOperation({
    summary:
      "Enregistrer une visite commerciale (questionnaire ABC Pilot) — limité au périmètre de l'appelant : hors périmètre = 404",
  })
  createVisiteCommerciale(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateVisiteCommercialeDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.createVisiteCommerciale(id, user, dto);
  }

  @Post(':id/appels')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_ACTIVITE_TERRAIN)
  @ApiOperation({
    summary:
      "Journaliser un appel passé au magasin — idempotent par idApk, limité au périmètre de l'appelant : hors périmètre = 404",
  })
  createAppel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateAppelClientDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.createAppel(id, user, dto);
  }

  @Post(':id/emails')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_ACTIVITE_TERRAIN)
  @ApiOperation({
    summary:
      "Journaliser un email envoyé au magasin — idempotent par idApk, limité au périmètre de l'appelant : hors périmètre = 404",
  })
  createEmail(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateEmailClientDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.createEmail(id, user, dto);
  }

  @Get(':id/journal-contacts')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({
    summary:
      "Derniers appels et emails du magasin (mêlés, plus récent en tête) — limité au périmètre de l'appelant : hors périmètre = 404",
  })
  journalContacts(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: UtilisateurPerimetre) {
    return this.clients.journalContacts(id, user);
  }

  @Post(':id/notes')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Ajouter une note terrain au magasin (limité au périmètre de l'appelant : hors périmètre = 404)" })
  addNote(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateNoteDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.addNote(id, dto.remarque, user, dto.idApk);
  }

  @Delete(':id/notes/:noteId')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Supprimer (logiquement) une note terrain (limité au périmètre : hors périmètre = 404)" })
  removeNote(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('noteId', ParseUUIDPipe) noteId: string,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.removeNote(id, noteId, user);
  }

  @Patch(':id/periodicite')
  @UseGuards(RolesGuard)
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({
    summary:
      "Définir la périodicité de visite du magasin (null = aucune) — limité au périmètre de l'appelant : hors périmètre = 404",
  })
  setPeriodicite(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetPeriodiciteDto,
    @CurrentUser() user: UtilisateurPerimetre,
  ) {
    return this.clients.setPeriodicite(id, dto.periodiciteId ?? null, user);
  }

  // Création, modification et suppression d'un client (référentiel Minos) : ADMIN seul. Aucun écran ni aucune appli
  // ne les appelle aujourd'hui ; les clients viennent de l'import AS400 et de la conversion d'un prospect.
  @Post()
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Créer un client (ADMIN)' })
  create(@Body() dto: CreateClientDto) {
    return this.clients.create(dto);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Mettre à jour un client (ADMIN)' })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateClientDto) {
    return this.clients.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Supprimer (logiquement) un client (ADMIN)' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.clients.remove(id);
  }
}

@ApiTags('clients')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('periodicites')
export class PeriodicitesController {
  constructor(private readonly clients: ClientsService) {}

  @Get()
  @ApiOperation({ summary: 'Nomenclature des périodicités de visite (référentiel legacy 1..6)' })
  list() {
    return this.clients.listPeriodicites();
  }
}
