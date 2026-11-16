import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { QuerySearchDto } from './dto/query-search.dto';
import { SearchService } from './search.service';

@ApiTags('search')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('search')
export class SearchController {
  constructor(private readonly search: SearchService) {}

  @Get()
  // Tous les rôles peuvent chercher ; ce qu'ils trouvent est borné famille par famille dans le service.
  @Roles(Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR, Role.COMMERCIAL, Role.ADV, Role.MARKETING)
  @ApiOperation({
    summary:
      'Recherche générale : clients, commandes, visites, collaborateurs, prospects et produits, filtrés par rôle et périmètre (5 lignes par famille)',
  })
  rechercher(@Query() query: QuerySearchDto, @CurrentUser() me: User) {
    return this.search.rechercher(me, query.q);
  }
}
