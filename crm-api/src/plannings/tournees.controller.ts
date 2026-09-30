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

/** Lundi (minuit UTC) de la semaine contenant `d` — colonne @db.Date. */
function lundiDe(d: string): Date {
  const x = new Date(d.slice(0, 10) + 'T00:00:00.000Z');
  x.setUTCDate(x.getUTCDate() - ((x.getUTCDay() + 6) % 7));
  return x;
}

const semaineSelect = { semaine: true, prevuAt: true, valideAt: true, nbEtapesPrevues: true } as const;

const etapeSelect = {
  id: true,
  adm: true,
  datePassage: true,
  fait: true,
  note: true,
  visiteSimple: true,
  accompagnement: true,
  rdv: true,
  soireeEtape: true,
  soireeLieu: true,
  soireeAdresse: true,
  client: { select: { id: true, codeAs400: true, enseigne: true, ville: true, niveauClass: true } },
  prospect: { select: { id: true, enseigne: true, ville: true, statut: true, niveauClass: true } },
} as const;

/**
 * TOURNÉE PERSONNELLE Helios (encadrement) : chacun planifie SES étapes —
 * visite d'un prospect ou suivi d'un magasin existant. Toujours scopé sur soi.
 * Distinct des visites planifiées des promoteurs (/plannings).
 */
@ApiTags('tournees')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
@Controller('tournees')
export class TourneesController {
  constructor(private readonly prisma: PrismaService) {}

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
  @ApiOperation({ summary: "État (prévision / validation) de MA semaine — `null` si rien d'enregistré" })
  async semaine(@Query('semaine') semaine: string, @CurrentUser() me: User) {
    if (!semaine) throw new BadRequestException('Paramètre `semaine` requis (yyyy-mm-dd).');
    const lundi = lundiDe(semaine);
    const ligne = await this.prisma.planningSemaine.findUnique({
      where: { userId_semaine: { userId: me.id, semaine: lundi } },
      select: semaineSelect,
    });
    return ligne ?? { semaine: lundi, prevuAt: null, valideAt: null, nbEtapesPrevues: null };
  }

  @Post('semaine/prevision')
  @ApiOperation({ summary: 'Enregistre la prévision de MA semaine (idempotent, refusé si déjà validée)' })
  async prevision(@Body() dto: SemaineDto, @CurrentUser() me: User) {
    const lundi = lundiDe(dto.semaine);
    const existante = await this.prisma.planningSemaine.findUnique({
      where: { userId_semaine: { userId: me.id, semaine: lundi } },
    });
    if (existante?.valideAt) throw new ConflictException('Cette semaine est déjà validée.');
    const nb = await this.nbEtapes(me.id, lundi);
    if (nb === 0) throw new BadRequestException('Aucune étape planifiée cette semaine.');
    return this.prisma.planningSemaine.upsert({
      where: { userId_semaine: { userId: me.id, semaine: lundi } },
      create: { userId: me.id, semaine: lundi, prevuAt: new Date(), nbEtapesPrevues: nb },
      update: { prevuAt: new Date(), nbEtapesPrevues: nb },
      select: semaineSelect,
    });
  }

  @Post('semaine/validation')
  @ApiOperation({ summary: 'Valide MA semaine (verrouille ; enregistre aussi la prévision si absente)' })
  async validation(@Body() dto: SemaineDto, @CurrentUser() me: User) {
    const lundi = lundiDe(dto.semaine);
    const existante = await this.prisma.planningSemaine.findUnique({
      where: { userId_semaine: { userId: me.id, semaine: lundi } },
    });
    if (existante?.valideAt) throw new ConflictException('Cette semaine est déjà validée.');
    const nb = await this.nbEtapes(me.id, lundi);
    if (nb === 0) throw new BadRequestException('Aucune étape planifiée cette semaine.');
    const maintenant = new Date();
    return this.prisma.planningSemaine.upsert({
      where: { userId_semaine: { userId: me.id, semaine: lundi } },
      create: { userId: me.id, semaine: lundi, prevuAt: maintenant, valideAt: maintenant, nbEtapesPrevues: nb },
      update: { valideAt: maintenant, prevuAt: existante?.prevuAt ?? maintenant, nbEtapesPrevues: existante?.nbEtapesPrevues ?? nb },
      select: semaineSelect,
    });
  }

  private nbEtapes(userId: string, lundi: Date): Promise<number> {
    const suivant = new Date(lundi);
    suivant.setUTCDate(suivant.getUTCDate() + 7);
    return this.prisma.tourneeEtape.count({
      where: { userId, deletedAt: null, datePassage: { gte: lundi, lt: suivant } },
    });
  }

  @Post()
  @ApiOperation({ summary: 'Ajoute une étape à MA tournée (prospect OU magasin existant) — idempotent par idApk' })
  async create(@Body() dto: CreateEtapeDto, @CurrentUser() me: User) {
    if (dto.adm) {
      if (dto.clientId || dto.prospectId) {
        throw new BadRequestException('Une étape ADM ne porte pas de cible magasin/prospect.');
      }
    } else if (!dto.clientId === !dto.prospectId) {
      throw new BadRequestException('Renseigner soit clientId, soit prospectId (exactement un des deux).');
    }
    // Rejeu de l'outbox mobile : l'étape existe déjà → on la renvoie telle quelle.
    if (dto.idApk) {
      const existante = await this.prisma.tourneeEtape.findFirst({
        where: { idApk: dto.idApk, userId: me.id },
        select: etapeSelect,
      });
      if (existante) return existante;
    }
    return this.prisma.tourneeEtape.create({
      data: {
        userId: me.id,
        adm: dto.adm ?? false,
        clientId: dto.clientId ?? null,
        prospectId: dto.prospectId ?? null,
        datePassage: new Date(dto.datePassage),
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
        ...(dto.datePassage ? { datePassage: new Date(dto.datePassage) } : {}),
        ...(dto.note !== undefined ? { note: dto.note.trim() || null } : {}),
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
    await this.prisma.tourneeEtape.update({ where: { id }, data: { deletedAt: new Date() } });
    return { ok: true };
  }
}
