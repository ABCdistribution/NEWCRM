import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { CommandesService } from './commandes.service';
import { CommandesApkService } from './commandes-apk.service';
import { CreateCommandeApkDto } from './dto/create-commande-apk.dto';
import { QueryCommandesDto } from './dto/query-commandes.dto';
import { QueryCommandesApkDto } from './dto/query-commandes-apk.dto';
import { UpdateLivraisonDto } from './dto/update-livraison.dto';

@ApiTags('commandes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('commandes')
export class CommandesController {
  constructor(
    private readonly commandes: CommandesService,
    private readonly commandesApk: CommandesApkService,
  ) {}

  @Post('apk')
  @ApiOperation({
    summary:
      "Commande saisie sur l'app mobile — idempotente par idCommandeApk (pont IDCRM avec la future commande Minos)",
  })
  createApk(@Body() dto: CreateCommandeApkDto, @CurrentUser() me: User) {
    return this.commandesApk.create(me, dto);
  }

  // Déclarée avant GET :id pour ne pas être happée par le ParseUUIDPipe.
  @Get('apk')
  @ApiOperation({ summary: 'Commandes mobiles du promoteur connecté (la direction voit tout)' })
  findAllApk(@Query() query: QueryCommandesApkDto, @CurrentUser() me: User) {
    return this.commandesApk.findAll(me, query);
  }

  @Get('apk/:id')
  @ApiOperation({ summary: "Détail d'une commande mobile avec ses lignes" })
  findOneApk(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    return this.commandesApk.findOne(me, id);
  }

  @Get()
  @ApiOperation({
    summary:
      'Liste paginée des commandes Minos (recherche, filtre annulées). Un commercial relié à un code représentant ne voit que les siennes.',
  })
  findAll(
    @Query() query: QueryCommandesDto,
    @CurrentUser() user: { role: string; idRepr: string | null },
  ) {
    return this.commandes.findAll(query, user);
  }

  @Get(':id')
  @ApiOperation({ summary: "Détail d'une commande avec ses lignes et son suivi de livraison" })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.commandes.findOne(id);
  }

  @Patch(':id/livraison')
  @UseGuards(RolesGuard)
  @Roles(Role.ADV, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({
    summary:
      'Mettre à jour le suivi de livraison (ADV · Direction · ADMIN) — EXPEDIEE/LIVREE posent les dates si absentes ; refusé sur une commande annulée',
  })
  updateLivraison(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateLivraisonDto) {
    return this.commandes.updateLivraison(id, dto);
  }
}
