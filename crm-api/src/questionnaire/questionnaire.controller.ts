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
import { IsBoolean, IsEnum, IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { Role, TypeQuestion, User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { QuestionnaireService } from './questionnaire.service';

class CreateQuestionDto {
  @ApiProperty({ example: 'La PLV de la promo en cours est-elle posée ?' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  libelle!: string;

  @ApiPropertyOptional({ enum: TypeQuestion, default: TypeQuestion.CASE_A_COCHER })
  @IsOptional()
  @IsEnum(TypeQuestion)
  type?: TypeQuestion;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  obligatoire?: boolean;
}

class UpdateQuestionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  libelle?: string;

  @ApiPropertyOptional({ enum: TypeQuestion })
  @IsOptional()
  @IsEnum(TypeQuestion)
  type?: TypeQuestion;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  obligatoire?: boolean;

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

@ApiTags('questionnaire')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('questionnaire')
export class QuestionnaireController {
  constructor(private readonly questionnaire: QuestionnaireService) {}

  @Get()
  @ApiOperation({
    summary:
      'Questionnaire de fin de visite : questions actives ordonnées (app mobile) — ?tous=1 pour inclure les inactives (édition)',
  })
  @ApiQuery({ name: 'tous', required: false })
  list(@Query('tous') tous?: string) {
    return this.questionnaire.list(tous === '1' || tous === 'true');
  }

  @Post('questions')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Ajouter une question (en fin de questionnaire)' })
  create(@Body() dto: CreateQuestionDto, @CurrentUser() me: User) {
    return this.questionnaire.create(
      dto.libelle.trim(),
      dto.type ?? TypeQuestion.CASE_A_COCHER,
      dto.obligatoire ?? false,
      me.id,
    );
  }

  @Patch('questions/:id')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Modifier une question (libellé, type, obligatoire, actif)' })
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateQuestionDto) {
    return this.questionnaire.update(id, dto);
  }

  @Post('questions/:id/deplacer')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: "Déplacer une question d'un cran vers le haut ou le bas" })
  deplacer(@Param('id', ParseUUIDPipe) id: string, @Body() dto: DeplacerDto) {
    return this.questionnaire.deplacer(id, dto.direction);
  }

  @Delete('questions/:id')
  @Roles(Role.ADMIN, Role.DIRECTION)
  @ApiOperation({ summary: 'Supprimer (logiquement) une question' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.questionnaire.remove(id);
  }
}
