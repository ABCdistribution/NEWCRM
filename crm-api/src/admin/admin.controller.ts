import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AdminService } from './admin.service';

/** Console d'administration (ABC Pilot) — lecture seule, réservée aux ADMIN. */
@ApiTags('admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('apercu')
  @ApiOperation({ summary: "Indicateurs de la vue d'ensemble : santé, comptes, cohérence de l'organisation, derniers imports" })
  apercu() {
    return this.admin.apercu();
  }

  @Get('organisation')
  @ApiOperation({ summary: 'Hiérarchie Région → Directeur → Chef de secteur → Promoteur et incohérences détectées' })
  organisation() {
    return this.admin.organisation();
  }
}
