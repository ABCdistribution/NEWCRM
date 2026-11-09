import {
  BadRequestException,
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
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsDateString, IsInt, IsNotEmpty, IsUUID, Max, Min } from 'class-validator';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { PlanningsService } from './plannings.service';

/** Rôles autorisés à modifier les plannings (« c'est pas les promoteurs qui font leur tournée »). */
const PLANIFICATEURS = [Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR] as const;

class MovePlanningDto {
  @ApiProperty({ example: '2026-09-02', description: 'Nouvelle date de passage (ISO)' })
  @IsDateString()
  @IsNotEmpty()
  datePassage!: string;
}

class CreatePlanningDto {
  @ApiProperty({ description: 'UUID du promoteur' })
  @IsUUID()
  promoteurId!: string;

  @ApiProperty({ description: 'UUID du client (magasin)' })
  @IsUUID()
  clientId!: string;

  @ApiProperty({ example: '2026-08-31', description: 'Date de passage (ISO)' })
  @IsDateString()
  @IsNotEmpty()
  datePassage!: string;
}

@ApiTags('plannings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('plannings')
export class PlanningsController {
  constructor(private readonly plannings: PlanningsService) {}

  @Get()
  @ApiOperation({ summary: "Visites planifiées d'un promoteur sur une période [debut, fin) — un commercial ne voit que les siennes" })
  @ApiQuery({ name: 'promoteurId', required: true })
  @ApiQuery({ name: 'debut', required: true, example: '2026-08-31' })
  @ApiQuery({ name: 'fin', required: true, example: '2026-09-07' })
  findPeriode(
    @CurrentUser() me: User,
    @Query('promoteurId', ParseUUIDPipe) promoteurId: string,
    @Query('debut') debut: string,
    @Query('fin') fin: string,
  ) {
    const d = new Date(debut);
    const f = new Date(fin);
    if (Number.isNaN(d.getTime()) || Number.isNaN(f.getTime()) || f <= d) {
      throw new BadRequestException('Période invalide');
    }
    return this.plannings.findPeriode(me, promoteurId, d, f);
  }

  @Get('client/:clientId')
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: "Visites planifiées À VENIR d'un magasin (suivi encadrement)" })
  findByClient(@CurrentUser() me: User, @Param('clientId', ParseUUIDPipe) clientId: string) {
    return this.plannings.findAVenirPourClient(me, clientId);
  }

  @Post()
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: 'Planifier une visite (direction)' })
  create(@CurrentUser() me: User, @Body() dto: CreatePlanningDto) {
    return this.plannings.create(me, dto.promoteurId, dto.clientId, new Date(dto.datePassage));
  }

  @Patch(':id')
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: 'Déplacer une visite planifiée vers une autre date' })
  move(@CurrentUser() me: User, @Param('id', ParseUUIDPipe) id: string, @Body() body: MovePlanningDto) {
    return this.plannings.move(me, id, new Date(body.datePassage));
  }

  @Delete(':id')
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: 'Retirer une visite planifiée (soft delete)' })
  remove(@CurrentUser() me: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.plannings.remove(me, id);
  }
}

class CreateRegleDto {
  @ApiProperty({ description: 'UUID du promoteur' })
  @IsUUID()
  promoteurId!: string;

  @ApiProperty({ description: 'UUID du client (magasin)' })
  @IsUUID()
  clientId!: string;

  @ApiProperty({ example: [1, 4], description: 'Jours ISO (1=lundi … 6=samedi)' })
  @IsArray()
  @ArrayNotEmpty()
  @Type(() => Number)
  @IsInt({ each: true })
  jours!: number[];

  @ApiProperty({ example: 1, description: 'Fréquence en semaines (1 = chaque semaine)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(8)
  recurrence!: number;

  @ApiProperty({ example: '2026-08-24', description: 'Date de début (ancre de la récurrence)' })
  @IsDateString()
  @IsNotEmpty()
  dateDebut!: string;
}

@ApiTags('plannings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('plannifications')
export class PlannificationsController {
  constructor(private readonly plannings: PlanningsService) {}

  @Get()
  @ApiOperation({ summary: "Règles de récurrence actives d'un promoteur — un commercial ne voit que les siennes" })
  @ApiQuery({ name: 'promoteurId', required: true })
  list(@CurrentUser() me: User, @Query('promoteurId', ParseUUIDPipe) promoteurId: string) {
    return this.plannings.listRegles(me, promoteurId);
  }

  @Post()
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: 'Créer une règle : magasin récurrent (jours × fréquence)' })
  create(@CurrentUser() me: User, @Body() dto: CreateRegleDto) {
    return this.plannings.createRegle(
      me,
      dto.promoteurId,
      dto.clientId,
      dto.jours,
      dto.recurrence,
      new Date(dto.dateDebut),
    );
  }

  @Delete(':id')
  @Roles(...PLANIFICATEURS)
  @ApiOperation({ summary: 'Supprimer une règle + ses occurrences futures non réalisées' })
  remove(@CurrentUser() me: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.plannings.removeRegle(me, id);
  }
}
