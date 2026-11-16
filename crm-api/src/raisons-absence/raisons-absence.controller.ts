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
import { IsBoolean, IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ROLES_COMMANDES_VISITES } from '../common/roles.constants';
import { RaisonsAbsenceService } from './raisons-absence.service';

class CreateRaisonDto {
  @ApiProperty({ description: "Libellé affiché dans l'app mobile" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  libelle!: string;
}

class UpdateRaisonDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  libelle?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  actif?: boolean;
}

class DeplacerDto {
  @ApiProperty({ enum: ['haut', 'bas'] })
  @IsIn(['haut', 'bas'])
  direction!: 'haut' | 'bas';
}

@ApiTags('raisons-absence-commande')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('raisons-absence-commande')
export class RaisonsAbsenceController {
  constructor(private readonly raisons: RaisonsAbsenceService) {}

  @Get()
  @Roles(...ROLES_COMMANDES_VISITES)
  @ApiOperation({
    summary:
      "Raisons d'absence de commande : actives ordonnées (app mobile) — ?tous=1 pour inclure les inactives (édition)",
  })
  @ApiQuery({ name: 'tous', required: false })
  list(@Query('tous') tous?: string) {
    return this.raisons.list(tous === '1' || tous === 'true');
  }

  @Post()
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Ajouter une raison (en fin de liste)' })
  create(@Body() dto: CreateRaisonDto) {
    return this.raisons.create(dto.libelle.trim());
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Modifier une raison (libellé, actif)' })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRaisonDto) {
    return this.raisons.update(id, {
      ...(dto.libelle !== undefined ? { libelle: dto.libelle.trim() } : {}),
      ...(dto.actif !== undefined ? { actif: dto.actif } : {}),
    });
  }

  @Post(':id/deplacer')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: "Déplacer une raison d'un cran vers le haut ou le bas" })
  deplacer(@Param('id', ParseUUIDPipe) id: string, @Body() dto: DeplacerDto) {
    return this.raisons.deplacer(id, dto.direction);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Supprimer (logiquement) une raison' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.raisons.remove(id);
  }
}
