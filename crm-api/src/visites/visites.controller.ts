import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { User } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { VisitesService } from './visites.service';

class ReponseDto {
  @ApiProperty({ description: 'UUID de la question du questionnaire' })
  @IsUUID()
  questionId!: string;

  @ApiProperty({ description: 'Valeur sérialisée selon le type (true/false, texte, nombre, note 1-5)' })
  @IsString()
  @MaxLength(2000)
  valeur!: string;
}

class CreateVisiteDto {
  @ApiProperty({ description: 'Identifiant généré côté mobile (clé d’idempotence de la sync)' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  idApk!: string;

  @ApiPropertyOptional({
    description: 'UUID du magasin visité — exactement un de clientId / prospectId',
  })
  @IsOptional()
  @IsUUID()
  clientId?: string;

  @ApiPropertyOptional({
    description: 'UUID du prospect visité (visite de prospection) — exactement un de clientId / prospectId',
  })
  @IsOptional()
  @IsUUID()
  prospectId?: string;

  @ApiPropertyOptional({ description: 'Visite planifiée soldée par ce compte-rendu' })
  @IsOptional()
  @IsUUID()
  planningId?: string;

  @ApiPropertyOptional({ example: 'Planifiée', description: 'Planifiée · Appel client · Passage opportunité · Urgence · Prospection…' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  motif?: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnAbc?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnConcurrence?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnGondoleHaute?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) dnGondoleBasse?: number;

  @ApiPropertyOptional({ description: 'Commentaire libre' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  commentaire?: string;

  @ApiPropertyOptional({ type: [ReponseDto], description: 'Réponses au questionnaire de fin de visite' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ReponseDto)
  reponses?: ReponseDto[];
}

class PhotoDto {
  @ApiPropertyOptional({ description: "Clé d'idempotence générée côté mobile (rejeu de l'outbox sans doublon)" })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  idApk?: string;
}

@ApiTags('visites')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('visites')
export class VisitesController {
  constructor(private readonly visites: VisitesService) {}

  @Get()
  @ApiOperation({
    summary:
      'Visites paginées — un commercial voit les siennes, les autres rôles (ADV, direction, CS, DR…) voient toutes les visites',
  })
  findAll(
    @Query('page') page: string | undefined,
    @Query('search') search: string | undefined,
    @CurrentUser() me: User,
  ) {
    const promoteurId = me.role === 'COMMERCIAL' ? me.id : null;
    return this.visites.findAll(promoteurId, { page: Number(page) || 1, search });
  }

  @Post()
  @ApiOperation({
    summary:
      "Compte-rendu de visite (app mobile) : questionnaire, DN, motif — idempotent par idApk, solde la visite planifiée liée",
  })
  create(@Body() dto: CreateVisiteDto, @CurrentUser() me: User) {
    return this.visites.create(me, dto);
  }

  @Post(':id/photos')
  @UseInterceptors(FileInterceptor('photo', { limits: { fileSize: 10 * 1024 * 1024 } }))
  @ApiOperation({
    summary: 'Photo de rayon attachée à une visite (multipart, champ « photo », 10 Mo max) — idempotent par idApk',
  })
  addPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() photo: { originalname: string; mimetype: string; size: number; buffer: Buffer } | undefined,
    @Body() dto: PhotoDto,
    @CurrentUser() me: User,
  ) {
    if (!photo) throw new BadRequestException('Aucune photo reçue (champ « photo »).');
    return this.visites.addPhoto(me, id, photo, dto.idApk);
  }

  @Get(':id/photos')
  @ApiOperation({ summary: "Photos d'une visite (métadonnées)" })
  listPhotos(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() me: User) {
    return this.visites.listPhotos(me, id);
  }

  @Get(':id/photos/:photoId')
  @ApiOperation({ summary: "Télécharger une photo de visite" })
  async getPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentUser() me: User,
    @Res() res: Response,
  ) {
    const p = await this.visites.getPhoto(me, id, photoId);
    res.setHeader('Content-Type', p.mime);
    res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(p.nom)}"`);
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(Buffer.from(p.donnees));
  }
}
