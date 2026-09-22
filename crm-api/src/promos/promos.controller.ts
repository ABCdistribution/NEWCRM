import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiQuery, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsDateString, IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PromosService } from './promos.service';

class CreatePromoDto {
  @ApiProperty({ description: "UUID de l'article en promo" })
  @IsUUID()
  articleId!: string;

  @ApiPropertyOptional({ example: '-20% jusqu’à fin du mois' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional({ description: 'Début (ISO) — vide = pas de borne' })
  @IsOptional()
  @IsDateString()
  dateDebut?: string;

  @ApiPropertyOptional({ description: 'Fin (ISO) — vide = pas de borne' })
  @IsOptional()
  @IsDateString()
  dateFin?: string;
}

class UpdatePromoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsDateString()
  dateDebut?: string | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsDateString()
  dateFin?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  actif?: boolean;
}

class AddPemDto {
  @ApiProperty({ description: "UUID de l'article à mettre en avant" })
  @IsUUID()
  articleId!: string;
}

@ApiTags('promos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('promos')
export class PromosController {
  constructor(private readonly promos: PromosService) {}

  // --- Promos -----------------------------------------------------------

  @Get()
  @ApiOperation({ summary: 'Liste des promos (?actives=1 pour seulement celles en cours)' })
  @ApiQuery({ name: 'actives', required: false })
  listPromos(@Query('actives') actives?: string) {
    return this.promos.listPromos(actives === '1' || actives === 'true');
  }

  @Post()
  @Roles(Role.ADMIN, Role.DIRECTION, Role.MARKETING)
  @ApiOperation({ summary: 'Créer une promo sur un article' })
  createPromo(@Body() dto: CreatePromoDto) {
    return this.promos.createPromo(dto);
  }

  // --- Mises en avant PEM (déclarées avant :id) -------------------------

  @Get('pem')
  @ApiOperation({ summary: 'Liste des articles mis en avant (PEM)' })
  listPem() {
    return this.promos.listPem();
  }

  @Post('pem')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.MARKETING)
  @ApiOperation({ summary: 'Mettre un article en avant (PEM)' })
  addPem(@Body() dto: AddPemDto) {
    return this.promos.addPem(dto.articleId);
  }

  @Delete('pem/:id')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.MARKETING)
  @ApiOperation({ summary: 'Retirer une mise en avant' })
  removePem(@Param('id', ParseUUIDPipe) id: string) {
    return this.promos.removePem(id);
  }

  // --- Promos (par id) --------------------------------------------------

  @Patch(':id')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.MARKETING)
  @ApiOperation({ summary: 'Modifier une promo (libellé, dates, actif)' })
  updatePromo(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdatePromoDto) {
    return this.promos.updatePromo(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.DIRECTION, Role.MARKETING)
  @ApiOperation({ summary: 'Supprimer une promo' })
  removePromo(@Param('id', ParseUUIDPipe) id: string) {
    return this.promos.removePromo(id);
  }
}
