import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { NewsService } from './news.service';
import { CreateNewsDto } from './dto/create-news.dto';
import { UpdateNewsDto } from './dto/update-news.dto';
import { ListNewsQuery } from './dto/list-news.query';

/** Tous les rôles : les news sont lisibles par tout utilisateur connecté. */
const TOUS_LES_ROLES = [
  Role.COMMERCIAL,
  Role.CHEF_SECTEUR,
  Role.DIRECTEUR_REGIONAL,
  Role.DIRECTION,
  Role.ADV,
  Role.MARKETING,
  Role.ADMIN,
];

/**
 * News du siège.
 *
 * Périmètre : les news sont GLOBALES (pas de filtrage utilisateur / secteur / région).
 * La restriction de lecture qui joue ici est la visibilité des brouillons : seuls MARKETING et ADMIN
 * les voient (liste et détail) ; les autres rôles ne reçoivent que les news publiées.
 * Écriture (créer, modifier, publier, supprimer) : MARKETING et ADMIN uniquement, vérifié côté serveur.
 */
@ApiTags('news')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('news')
export class NewsController {
  constructor(private readonly news: NewsService) {}

  @Get()
  @Roles(...TOUS_LES_ROLES)
  @ApiOperation({ summary: 'Liste paginée des news (brouillons visibles seulement par MARKETING / ADMIN)' })
  list(@Query() q: ListNewsQuery, @CurrentUser() user: { role: string }) {
    return this.news.list(user.role, q.page, q.pageSize);
  }

  @Get(':id')
  @Roles(...TOUS_LES_ROLES)
  @ApiOperation({ summary: 'Détail d’une news (404 pour un brouillon si non administrateur)' })
  get(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: { role: string }) {
    return this.news.get(id, user.role);
  }

  @Post()
  @Roles(Role.ADMIN, Role.MARKETING)
  @ApiOperation({ summary: 'Créer une news (auteur = utilisateur connecté)' })
  create(@Body() dto: CreateNewsDto, @CurrentUser() user: { id: string }) {
    return this.news.create(dto, user.id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.MARKETING)
  @ApiOperation({ summary: 'Modifier / publier / dépublier une news' })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateNewsDto) {
    return this.news.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.MARKETING)
  @ApiOperation({ summary: 'Supprimer une news (suppression logique)' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.news.remove(id);
  }
}
