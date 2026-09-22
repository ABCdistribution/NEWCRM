import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength, ValidateIf } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@crm/database';
import { SecteursService } from './secteurs.service';

class CreateSecteurDto {
  @ApiProperty({ example: 'SE' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(10)
  code!: string;

  @ApiProperty({ example: 'Sud-Est' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  nom!: string;

  @ApiPropertyOptional({ description: 'UUID du chef de secteur', nullable: true })
  @IsOptional()
  @ValidateIf((o: CreateSecteurDto) => o.managerId !== null)
  @IsUUID()
  managerId?: string | null;
}

class UpdateSecteurDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(60)
  nom?: string;

  @ApiPropertyOptional({ description: 'UUID du chef de secteur (null pour retirer)', nullable: true })
  @IsOptional()
  @ValidateIf((o: UpdateSecteurDto) => o.managerId !== null)
  @IsUUID()
  managerId?: string | null;
}

@ApiTags('secteurs')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('secteurs')
export class SecteursController {
  constructor(private readonly secteurs: SecteursService) {}

  @Get()
  @ApiOperation({ summary: 'Liste des secteurs (chef, nb membres, nb clients)' })
  list() {
    return this.secteurs.list();
  }

  @Post()
  @ApiOperation({ summary: 'Créer un secteur' })
  create(@Body() dto: CreateSecteurDto) {
    return this.secteurs.create(dto.code, dto.nom, dto.managerId ?? null);
  }

  @Patch(':id')
  @ApiOperation({ summary: "Modifier un secteur (nom, chef)" })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateSecteurDto) {
    return this.secteurs.update(id, dto);
  }
}
