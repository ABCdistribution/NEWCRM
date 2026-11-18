import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { CommandesService } from './commandes.service';
import { CommandesApkService } from './commandes-apk.service';
import { CreateCommandeApkDto } from './dto/create-commande-apk.dto';
import { QueryCommandesDto } from './dto/query-commandes.dto';
import { QueryCommandesApkDto } from './dto/query-commandes-apk.dto';
import { EnvoyerMailCommandeApkDto, UpdateCommandeApkDto } from './dto/update-commande-apk.dto';
import { UpdateLivraisonDto } from './dto/update-livraison.dto';

@ApiTags('commandes')
@ApiBearerAuth()
// Pas d'accès pour le marketing ; la mise à jour de la livraison garde sa propre liste de rôles (méthode, prioritaire).
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(...ROLES_COMMANDES_VISITES)
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

  // Écritures sur une commande mobile : promoteur propriétaire uniquement (admin, direction, encadrement : lecture seule).
  @Patch('apk/:id')
  @Roles(Role.COMMERCIAL)
  @ApiOperation({ summary: 'Modifier une commande mobile EN_ATTENTE (propriétaire) — 409 si déjà validée' })
  updateApk(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCommandeApkDto, @CurrentUser() me: User) {
    return this.commandesApk.update(me, id, dto);
  }

  @Post('apk/:id/valider')
  @HttpCode(200)
  @Roles(Role.COMMERCIAL)
  @ApiOperation({ summary: 'Valider une commande mobile EN_ATTENTE (propriétaire) — idempotent' })
  validerApk(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    return this.commandesApk.valider(me, id);
  }

  @Post('apk/:id/envoyer-mail')
  @HttpCode(200)
  @Roles(Role.COMMERCIAL)
  @ApiOperation({
    summary:
      "Envoyer une commande EN_ATTENTE par mail au client pour validation (propriétaire) — elle reste EN_ATTENTE ; 503 sans SMTP, 429 si renvoi en moins d'une minute",
  })
  envoyerMailApk(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: EnvoyerMailCommandeApkDto,
    @CurrentUser() me: User,
  ) {
    return this.commandesApk.envoyerMail(me, id, dto.email);
  }

  @Delete('apk/:id')
  @Roles(Role.COMMERCIAL)
  @ApiOperation({ summary: 'Supprimer une commande mobile EN_ATTENTE (propriétaire) — interdit si validée' })
  removeApk(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    return this.commandesApk.remove(me, id);
  }

  @Get()
  @ApiOperation({
    summary:
      'Liste paginée des commandes Minos (recherche, filtre annulées). Un commercial relié à un code représentant ne voit que les siennes.',
  })
  findAll(
    @Query() query: QueryCommandesDto,
    @CurrentUser() user: { id: string; role: string; idRepr: string | null; regionId: string | null },
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
