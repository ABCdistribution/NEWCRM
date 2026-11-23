import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiQuery, ApiTags } from '@nestjs/swagger';
import { IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { ProduitsIndispensablesService } from './produits-indispensables.service';

class CreateProduitIndispensableDto {
  @ApiProperty({ description: "UUID de l'enseigne (centrale)" })
  @IsUUID(undefined, { message: "centraleId doit être l'identifiant d'une enseigne" })
  centraleId!: string;

  @ApiProperty({ description: "UUID de l'article" })
  @IsUUID(undefined, { message: "articleId doit être l'identifiant d'un article" })
  articleId!: string;

  @ApiPropertyOptional({ description: 'Position dans la liste (défaut 0)' })
  @IsOptional()
  @IsInt({ message: "L'ordre doit être un entier" })
  @Min(0, { message: "L'ordre ne peut pas être négatif" })
  @Max(100000, { message: "L'ordre ne doit pas dépasser 100000" })
  ordre?: number;
}

class UpdateProduitIndispensableDto {
  @ApiProperty({ description: 'Nouvelle position dans la liste' })
  @IsInt({ message: "L'ordre doit être un entier" })
  @Min(0, { message: "L'ordre ne peut pas être négatif" })
  @Max(100000, { message: "L'ordre ne doit pas dépasser 100000" })
  ordre!: number;
}

/**
 * Lecture : tous les rôles qui lisent les visites (le marketing n'y a pas accès) ; la liste est la même pour toute une
 * enseigne ; la route par magasin vérifie en revanche que le magasin est dans le périmètre de l'appelant.
 * Écriture : ADMIN seul.
 */
@ApiTags('produits-indispensables')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('produits-indispensables')
export class ProduitsIndispensablesController {
  constructor(private readonly produits: ProduitsIndispensablesService) {}

  @Get()
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Produits indispensables d'une enseigne (?centraleId=) ou de toutes les enseignes" })
  @ApiQuery({ name: 'centraleId', required: false })
  list(@Query('centraleId', new ParseUUIDPipe({ optional: true })) centraleId?: string) {
    return this.produits.list(centraleId);
  }

  @Get('client/:clientId')
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({ summary: "Produits indispensables de l'enseigne (centrale) du magasin, magasin dans le périmètre de l'appelant (sinon 404) — liste vide sans centrale" })
  listPourClient(
    @Param('clientId', ParseUUIDPipe) clientId: string,
    @CurrentUser() user: { id: string; role: string; idRepr: string | null; regionId: string | null },
  ) {
    return this.produits.listPourClient(clientId, user);
  }

  @Post()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Ajouter un produit à une enseigne (idempotent : restaure un produit supprimé)' })
  create(@Body() dto: CreateProduitIndispensableDto) {
    return this.produits.create(dto.centraleId, dto.articleId, dto.ordre);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: "Modifier la position d'un produit" })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateProduitIndispensableDto) {
    return this.produits.update(id, dto.ordre);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Retirer un produit de la liste (suppression logique)' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.produits.remove(id);
  }
}
