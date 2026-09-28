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
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ClientsService } from './clients.service';
import { CreateClientDto } from './dto/create-client.dto';
import { UpdateClientDto } from './dto/update-client.dto';
import { QueryClientsDto } from './dto/query-clients.dto';
import { CreateContactDto, UpdateContactDto } from './dto/contact.dto';

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
    @CurrentUser() user: { role: string; idRepr: string | null },
  ) {
    return this.clients.findAll(query, user);
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
  @ApiOperation({
    summary:
      'Contacts et notes de tout le portefeuille en un appel (réplication mobile hors ligne)',
  })
  fiches(@CurrentUser() user: { role: string; idRepr: string | null }) {
    return this.clients.findFiches(user);
  }

  @Get(':id')
  @ApiOperation({ summary: "Détail d'un client" })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.clients.findOneDetail(id);
  }

  @Get(':id/historique')
  @ApiOperation({ summary: 'Historique du magasin : commandes, visites, CA mensuel N / N-1' })
  historique(@Param('id', ParseUUIDPipe) id: string) {
    return this.clients.findHistorique(id);
  }

  @Post(':id/contacts')
  @ApiOperation({ summary: 'Ajouter un contact au magasin' })
  addContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateContactDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.addContact(id, dto, user.id);
  }

  @Patch(':id/contacts/:contactId')
  @ApiOperation({ summary: 'Modifier un contact du magasin' })
  updateContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('contactId', ParseUUIDPipe) contactId: string,
    @Body() dto: UpdateContactDto,
  ) {
    return this.clients.updateContact(id, contactId, dto);
  }

  @Delete(':id/contacts/:contactId')
  @ApiOperation({ summary: 'Supprimer (logiquement) un contact du magasin' })
  removeContact(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('contactId', ParseUUIDPipe) contactId: string,
  ) {
    return this.clients.removeContact(id, contactId);
  }

  @Post(':id/visites-commerciales')
  @ApiOperation({ summary: 'Enregistrer une visite commerciale (questionnaire Helios)' })
  createVisiteCommerciale(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateVisiteCommercialeDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.createVisiteCommerciale(id, user.id, dto);
  }

  @Post(':id/appels')
  @ApiOperation({ summary: 'Journaliser un appel passé au magasin — idempotent par idApk' })
  createAppel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateAppelClientDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.createAppel(id, user.id, dto);
  }

  @Post(':id/emails')
  @ApiOperation({ summary: 'Journaliser un email envoyé au magasin — idempotent par idApk' })
  createEmail(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateEmailClientDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.createEmail(id, user.id, dto);
  }

  @Get(':id/journal-contacts')
  @ApiOperation({ summary: 'Derniers appels et emails du magasin (mêlés, plus récent en tête)' })
  journalContacts(@Param('id', ParseUUIDPipe) id: string) {
    return this.clients.journalContacts(id);
  }

  @Post(':id/notes')
  @ApiOperation({ summary: 'Ajouter une note terrain au magasin' })
  addNote(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateNoteDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.addNote(id, dto.remarque, user.id, dto.idApk);
  }

  @Delete(':id/notes/:noteId')
  @ApiOperation({ summary: 'Supprimer (logiquement) une note terrain' })
  removeNote(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('noteId', ParseUUIDPipe) noteId: string,
  ) {
    return this.clients.removeNote(id, noteId);
  }

  @Patch(':id/periodicite')
  @ApiOperation({ summary: 'Définir la périodicité de visite du magasin (null = aucune)' })
  setPeriodicite(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetPeriodiciteDto,
    @CurrentUser() user: { id: string },
  ) {
    return this.clients.setPeriodicite(id, dto.periodiciteId ?? null, user.id);
  }

  @Post()
  @ApiOperation({ summary: 'Créer un client' })
  create(@Body() dto: CreateClientDto) {
    return this.clients.create(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Mettre à jour un client' })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateClientDto) {
    return this.clients.update(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Supprimer (logiquement) un client' })
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
