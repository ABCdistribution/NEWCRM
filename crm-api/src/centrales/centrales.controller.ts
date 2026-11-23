import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CentralesService } from './centrales.service';

/** Lecture seule des enseignes : nomenclature d'achat, sans donnée de magasin (aucun filtre de périmètre). */
@ApiTags('centrales')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('centrales')
export class CentralesController {
  constructor(private readonly centrales: CentralesService) {}

  @Get()
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: "Enseignes (centrales) avec leur nombre de magasins rattachés, les plus fournies d'abord" })
  list() {
    return this.centrales.list();
  }
}
