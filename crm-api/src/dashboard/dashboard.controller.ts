import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DashboardService } from './dashboard.service';

@ApiTags('dashboard')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('dashboard')
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Get('me')
  @ApiOperation({ summary: 'Chiffres du tableau de bord de l\'utilisateur courant (scopé sur son idRepr, sinon global)' })
  me(@CurrentUser() user: User) {
    return this.dashboard.forUser(user);
  }

  @Get('direction')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR)
  @ApiOperation({
    summary:
      'Dashboard de pilotage (helios) : CA consolidé N/N-1, classement des promoteurs, CA par secteur, objectifs, magasins sans commande — un chef de secteur est restreint à ses secteurs',
  })
  @ApiQuery({ name: 'annee', required: false, example: 2026 })
  @ApiQuery({ name: 'mois', required: false, example: 8 })
  direction(
    @CurrentUser() user: User,
    @Query('annee') anneeQ?: string,
    @Query('mois') moisQ?: string,
  ) {
    const now = new Date();
    const annee = Number(anneeQ) || now.getFullYear();
    const mois = Math.min(12, Math.max(1, Number(moisQ) || now.getMonth() + 1));
    return this.dashboard.direction(user, annee, mois);
  }
}
