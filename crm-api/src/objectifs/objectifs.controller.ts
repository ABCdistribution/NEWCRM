import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiQuery, ApiTags } from '@nestjs/swagger';
import { IsInt, IsNumber, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ObjectifsService } from './objectifs.service';

class UpsertObjectifDto {
  @ApiProperty({ description: 'UUID du magasin' })
  @IsUUID()
  clientId!: string;

  @ApiProperty({ example: 2026 })
  @IsInt()
  @Min(2000)
  @Max(2100)
  annee!: number;

  @ApiProperty({ example: 24000, nullable: true, description: 'Cible CA ANNUELLE en euros (null pour supprimer)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  cibleCa!: number | null;
}

/**
 * Objectifs de CA annuels PAR MAGASIN — saisie réservée à la direction
 * (Grégory Sylvestre) et aux admins.
 */
@ApiTags('objectifs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN, Role.DIRECTION)
@Controller('objectifs')
export class ObjectifsController {
  constructor(private readonly objectifs: ObjectifsService) {}

  @Get()
  @ApiOperation({
    summary: "Grille annuelle : tous les magasins actifs (recherche + pagination), objectif de l'année, CA réalisé",
  })
  @ApiQuery({ name: 'annee', required: false, type: Number })
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  grille(
    @Query('annee') annee?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
  ) {
    const a = Number(annee) || new Date().getFullYear();
    const p = Math.max(1, Number(page) || 1);
    return this.objectifs.grille(a, search?.trim() || undefined, p);
  }

  @Put()
  @ApiOperation({ summary: "Créer / modifier / supprimer (cibleCa: null) l'objectif annuel d'un magasin" })
  upsert(@Body() dto: UpsertObjectifDto, @CurrentUser() me: User) {
    return this.objectifs.upsert(dto.clientId, dto.annee, dto.cibleCa ?? null, me.id);
  }
}
