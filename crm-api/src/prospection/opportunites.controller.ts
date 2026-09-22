import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { OpportunitesService } from './opportunites.service';
import { CreateOpportuniteDto, QueryOpportunitesDto, UpdateOpportuniteDto } from './dto/opportunite.dto';

@ApiTags('prospection')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('opportunites')
export class OpportunitesController {
  constructor(private readonly opportunites: OpportunitesService) {}

  @Get()
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({
    summary:
      'Liste paginée des opportunités (type, statut, prospectId, clientId) — scopée comme les prospects',
  })
  findAll(@Query() query: QueryOpportunitesDto, @CurrentUser() user: User) {
    return this.opportunites.findAll(user, query);
  }

  @Post()
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({
    summary:
      'Créer une opportunité (référencement / OP / mise en avant) — portée par exactement un prospect OU un client, avec articles visés',
  })
  create(@Body() dto: CreateOpportuniteDto, @CurrentUser() user: User) {
    return this.opportunites.create(user, dto);
  }

  @Patch(':id')
  @Roles(Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.ADMIN)
  @ApiOperation({ summary: 'Faire évoluer une opportunité (statut, articles, valeur, période, responsable)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOpportuniteDto,
    @CurrentUser() user: User,
  ) {
    return this.opportunites.update(user, id, dto);
  }
}
