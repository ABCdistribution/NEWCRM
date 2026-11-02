import { BadRequestException, Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RapportsService } from './rapports.service';
import { lundiDe } from './rapport-semaine.util';

/**
 * CONSULTATION des rapports d'activité hebdomadaires des chefs de secteur et directeurs régionaux (lecture seule).
 * La saisie se fait sur `/tournees` : chacun ne saisit que son propre rapport. Périmètre : direction et administrateurs
 * voient tout ; un directeur régional voit sa région et son équipe.
 */
@ApiTags('rapports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
@Controller('rapports')
export class RapportsController {
  constructor(private readonly rapports: RapportsService) {}

  @Get()
  @ApiOperation({ summary: "Rapports de la semaine de mon périmètre : prévision, tournée réalisée, validation (« Validé auto » inclus)" })
  liste(@Query('semaine') semaine: string, @CurrentUser() me: User) {
    if (!semaine) throw new BadRequestException('Paramètre `semaine` requis (yyyy-mm-dd).');
    return this.rapports.liste(me, lundiDe(semaine));
  }

  @Get(':userId')
  @ApiOperation({ summary: "Détail d'un rapport : tournée prévue (photographie) et tournée réalisée / rapport validé" })
  detail(@Param('userId', ParseUUIDPipe) userId: string, @Query('semaine') semaine: string, @CurrentUser() me: User) {
    if (!semaine) throw new BadRequestException('Paramètre `semaine` requis (yyyy-mm-dd).');
    return this.rapports.detail(me, userId, lundiDe(semaine));
  }
}
