import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsDateString, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { icalToken } from './ical.controller';
import { RapportsService } from './rapports.service';
import { dateDePassage, lundiDe } from './rapport-semaine.util';

class CreateEtapeDto {
  @ApiPropertyOptional({ description: 'Étape ADM (administrative) — aucune cible magasin/prospect' })
  @IsOptional()
  @IsBoolean()
  adm?: boolean;

  @ApiPropertyOptional({ description: 'Magasin existant (exactement un des deux avec prospectId)' })
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @ApiPropertyOptional({ description: 'Prospect (exactement un des deux avec clientId)' })
  @IsOptional()
  @IsUUID()
  prospectId?: string;

  @ApiPropertyOptional({ description: "Client ou lieu en texte libre (rapport d'activité), à la place de clientId / prospectId" })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional({ description: 'Adresse de la ligne (texte libre)' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  adresse?: string;

  @ApiPropertyOptional({ description: 'Date de passage (yyyy-mm-dd ou ISO)' })
  @IsDateString()
  datePassage!: string;

  @ApiPropertyOptional({ description: 'Observations' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @ApiPropertyOptional({ description: 'Visite simple' })
  @IsOptional()
  @IsBoolean()
  visiteSimple?: boolean;

  @ApiPropertyOptional({ description: 'Accompagnement promoteur' })
  @IsOptional()
  @IsBoolean()
  accompagnement?: boolean;

  @ApiPropertyOptional({ description: 'Passage sur rendez-vous' })
  @IsOptional()
  @IsBoolean()
  rdv?: boolean;

  @ApiPropertyOptional({ description: 'Soirée étape (découcher)' })
  @IsOptional()
  @IsBoolean()
  soireeEtape?: boolean;

  @ApiPropertyOptional({ description: "Lieu de l'étape (si soirée étape)" })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  soireeLieu?: string;

  @ApiPropertyOptional({ description: "Adresse de l'étape (si soirée étape)" })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  soireeAdresse?: string;

  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile (rejeu de l'outbox sans doublon)" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

class UpdateEtapeDto {
  @ApiPropertyOptional({ description: 'Client ou lieu en texte libre' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional({ description: 'Adresse de la ligne' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  adresse?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  fait?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  datePassage?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @ApiPropertyOptional({ description: 'Requalification : visite simple' })
  @IsOptional()
  @IsBoolean()
  visiteSimple?: boolean;

  @ApiPropertyOptional({ description: 'Requalification : accompagnement promoteur' })
  @IsOptional()
  @IsBoolean()
  accompagnement?: boolean;

  @ApiPropertyOptional({ description: 'Requalification : passage sur rendez-vous' })
  @IsOptional()
  @IsBoolean()
  rdv?: boolean;

  @ApiPropertyOptional({ description: 'Requalification : soirée étape (découcher)' })
  @IsOptional()
  @IsBoolean()
  soireeEtape?: boolean;

  @ApiPropertyOptional({ description: "Lieu de l'étape (si soirée étape)" })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  soireeLieu?: string;

  @ApiPropertyOptional({ description: "Adresse de l'étape (si soirée étape)" })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  soireeAdresse?: string;
}

class SemaineDto {
  @ApiPropertyOptional({ description: 'Une date de la semaine (yyyy-mm-dd) — normalisée au lundi' })
  @IsDateString()
  semaine!: string;
}

const etapeSelect = {
  id: true,
  adm: true,
  libelle: true,
  adresse: true,
  datePassage: true,
  fait: true,
  note: true,
  visiteSimple: true,
  accompagnement: true,
  rdv: true,
  soireeEtape: true,
  soireeLieu: true,
  soireeAdresse: true,
  // Adresse et coordonnées : pour l'itinéraire depuis l'application mobile.
  client: {
    select: {
      id: true, codeAs400: true, enseigne: true, ville: true, niveauClass: true,
      adresse1: true, codePostal: true, latitude: true, longitude: true,
    },
  },
  prospect: {
    select: {
      id: true, enseigne: true, ville: true, statut: true, niveauClass: true,
      adresse1: true, codePostal: true, latitude: true, longitude: true,
    },
  },
} as const;

/**
 * TOURNÉE PERSONNELLE ABC Pilot (encadrement) : chacun planifie SES étapes —
 * visite d'un prospect ou suivi d'un magasin existant. Toujours scopé sur soi.
 * Distinct des visites planifiées des promoteurs (/plannings).
 */
@ApiTags('tournees')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
@Controller('tournees')
export class TourneesController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rapports: RapportsService,
  ) {}

  @Get('me')
  @ApiOperation({ summary: 'Mes étapes de tournée sur [debut, fin) — prospects et magasins mêlés' })
  async mes(
    @Query('debut') debut: string,
    @Query('fin') fin: string,
    @CurrentUser() me: User,
  ) {
    return this.prisma.tourneeEtape.findMany({
      where: {
        userId: me.id,
        deletedAt: null,
        ...(debut && fin ? { datePassage: { gte: new Date(debut), lt: new Date(fin) } } : {}),
      },
      orderBy: { datePassage: 'asc' },
      select: etapeSelect,
    });
  }

  @Get('ical-token')
  @ApiOperation({ summary: "Jeton personnel du flux iCal (abonnement Outlook au planning d'activité)" })
  icalToken(@CurrentUser() me: User) {
    return { userId: me.id, token: icalToken(me.id) };
  }

  @Get('user/:userId')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR)
  @ApiOperation({ summary: "Planning d'activité d'un MEMBRE DE MON ÉQUIPE sur [debut, fin) (lecture seule)" })
  async planningDe(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query('debut') debut: string,
    @Query('fin') fin: string,
    @CurrentUser() me: User,
  ) {
    const cible = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, displayName: true, poste: true, directeurId: true, regionId: true },
    });
    if (!cible) throw new NotFoundException(`Utilisateur ${userId} introuvable`);
    // ADMIN / DIRECTION voient tout ; un DR (ou CS) ne voit que sa propre équipe AD.
    const encadreTout = me.role === 'ADMIN' || me.role === 'DIRECTION';
    if (!encadreTout && cible.directeurId !== me.id && cible.id !== me.id) {
      throw new NotFoundException(`Utilisateur ${userId} hors de votre équipe`);
    }
    const etapes = await this.prisma.tourneeEtape.findMany({
      where: {
        userId,
        deletedAt: null,
        ...(debut && fin ? { datePassage: { gte: new Date(debut), lt: new Date(fin) } } : {}),
      },
      orderBy: { datePassage: 'asc' },
      select: etapeSelect,
    });
    return { user: { id: cible.id, displayName: cible.displayName, poste: cible.poste }, etapes };
  }

  @Get('semaine')
  @ApiOperation({
    summary:
      "État de MA semaine : phase (prévision jusqu'au lundi soir, puis rapport), prévision enregistrée ou « non renseignée », validation (manuelle ou automatique)",
  })
  async semaine(@Query('semaine') semaine: string, @CurrentUser() me: User) {
    if (!semaine) throw new BadRequestException('Paramètre `semaine` requis (yyyy-mm-dd).');
    return this.rapports.etat(me.id, lundiDe(semaine));
  }

  @Get('semaine/prevue')
  @ApiOperation({ summary: 'Tournée PRÉVUE de MA semaine (la photographie enregistrée) — null si la prévision n\'a pas été renseignée' })
  async prevue(@Query('semaine') semaine: string, @CurrentUser() me: User) {
    if (!semaine) throw new BadRequestException('Paramètre `semaine` requis (yyyy-mm-dd).');
    return { prevue: await this.rapports.prevuePour(me.id, lundiDe(semaine)) };
  }

  @Post('semaine/prevision')
  @ApiOperation({
    summary:
      "Enregistre la tournée PRÉVUE de MA semaine (photographie des étapes) : modifiable jusqu'au lundi soir, figée dès le mardi ; refusée si vide",
  })
  prevision(@Body() dto: SemaineDto, @CurrentUser() me: User) {
    return this.rapports.enregistrerPrevision(me.id, lundiDe(dto.semaine));
  }

  @Post('semaine/validation')
  @ApiOperation({
    summary:
      'Valide le rapport de MA semaine (dès le mardi) : la tournée réalisée devient définitive et la semaine est verrouillée. Rapport vide : reprend la prévision si elle existe, sinon refusé',
  })
  validation(@Body() dto: SemaineDto, @CurrentUser() me: User) {
    return this.rapports.valider(me.id, lundiDe(dto.semaine));
  }

  @Post()
  @ApiOperation({ summary: 'Ajoute une étape à MA tournée (prospect OU magasin existant) — idempotent par idApk' })
  async create(@Body() dto: CreateEtapeDto, @CurrentUser() me: User) {
    if (dto.adm) {
      if (dto.clientId || dto.prospectId) {
        throw new BadRequestException('Une étape ADM ne porte pas de cible magasin/prospect.');
      }
    } else if (dto.libelle?.trim()) {
      // Saisie libre du rapport d'activité : du texte à la place d'un client ou d'un prospect de la liste.
      if (dto.clientId || dto.prospectId) {
        throw new BadRequestException('Une ligne libre ne porte pas de clientId / prospectId.');
      }
    } else if (!dto.clientId === !dto.prospectId) {
      throw new BadRequestException('Renseigner soit clientId, soit prospectId (exactement un des deux), ou un libellé libre.');
    }
    // Rejeu de l'outbox mobile : l'étape existe déjà → on la renvoie telle quelle.
    if (dto.idApk) {
      const existante = await this.prisma.tourneeEtape.findFirst({
        where: { idApk: dto.idApk, userId: me.id },
        select: etapeSelect,
      });
      if (existante) return existante;
    }
    // Une semaine validée est verrouillée : plus aucune ligne ne s'y ajoute.
    await this.rapports.verifierModifiable(me.id, dateDePassage(dto.datePassage));
    return this.prisma.tourneeEtape.create({
      data: {
        userId: me.id,
        adm: dto.adm ?? false,
        libelle: dto.adm ? null : dto.libelle?.trim() || null,
        adresse: dto.adresse?.trim() || null,
        clientId: dto.clientId ?? null,
        prospectId: dto.prospectId ?? null,
        datePassage: dateDePassage(dto.datePassage),
        note: dto.note?.trim() || null,
        visiteSimple: dto.visiteSimple ?? !dto.accompagnement,
        accompagnement: dto.accompagnement ?? false,
        rdv: dto.rdv ?? false,
        soireeEtape: dto.soireeEtape ?? false,
        soireeLieu: dto.soireeEtape ? dto.soireeLieu?.trim() || null : null,
        soireeAdresse: dto.soireeEtape ? dto.soireeAdresse?.trim() || null : null,
        idApk: dto.idApk ?? null,
      },
      select: etapeSelect,
    });
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Modifie une étape de MA tournée (fait, date, note, qualification)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateEtapeDto,
    @CurrentUser() me: User,
  ) {
    const etape = await this.prisma.tourneeEtape.findFirst({
      where: { id, userId: me.id, deletedAt: null },
    });
    if (!etape) throw new NotFoundException(`Étape ${id} introuvable`);
    // Une semaine validée est verrouillée (et on ne déplace pas une étape vers une semaine validée).
    await this.rapports.verifierModifiable(me.id, etape.datePassage);
    if (dto.datePassage) await this.rapports.verifierModifiable(me.id, dateDePassage(dto.datePassage));

    // Requalification : on ne touche à la qualification que si un de ses champs est fourni.
    const requalifie = [dto.visiteSimple, dto.accompagnement, dto.rdv, dto.soireeEtape, dto.soireeLieu, dto.soireeAdresse]
      .some((v) => v !== undefined);
    let qualif = {};
    if (requalifie) {
      const accompagnement = dto.accompagnement ?? etape.accompagnement;
      const soireeEtape = dto.soireeEtape ?? etape.soireeEtape;
      qualif = {
        accompagnement,
        visiteSimple: dto.visiteSimple ?? (dto.accompagnement !== undefined ? !accompagnement : etape.visiteSimple),
        rdv: dto.rdv ?? etape.rdv,
        soireeEtape,
        soireeLieu: soireeEtape ? (dto.soireeLieu ?? etape.soireeLieu)?.trim() || null : null,
        soireeAdresse: soireeEtape ? (dto.soireeAdresse ?? etape.soireeAdresse)?.trim() || null : null,
      };
    }

    return this.prisma.tourneeEtape.update({
      where: { id },
      data: {
        ...(dto.fait !== undefined ? { fait: dto.fait } : {}),
        ...(dto.datePassage ? { datePassage: dateDePassage(dto.datePassage) } : {}),
        ...(dto.note !== undefined ? { note: dto.note.trim() || null } : {}),
        ...(dto.libelle !== undefined && !etape.adm ? { libelle: dto.libelle.trim() || null } : {}),
        ...(dto.adresse !== undefined ? { adresse: dto.adresse.trim() || null } : {}),
        ...qualif,
      },
      select: etapeSelect,
    });
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Retire une étape de MA tournée (soft delete)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    const etape = await this.prisma.tourneeEtape.findFirst({
      where: { id, userId: me.id, deletedAt: null },
    });
    if (!etape) throw new NotFoundException(`Étape ${id} introuvable`);
    await this.rapports.verifierModifiable(me.id, etape.datePassage);
    await this.prisma.tourneeEtape.update({ where: { id }, data: { deletedAt: new Date() } });
    return { ok: true };
  }
}
