import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsNotEmpty, IsString, IsUUID, MaxLength } from 'class-validator';
import { Role } from '@crm/database';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';

class RelanceDto {
  @ApiProperty({ description: 'UUID de la visite planifiée à relancer' })
  @IsUUID()
  planningId!: string;
}

class RelanceMembreDto {
  @ApiProperty({ description: "UUID du membre de l'équipe à relancer (ex. un chef de secteur)" })
  @IsUUID()
  userId!: string;

  @ApiProperty({ example: 'Merci de mettre à jour ton planning de la semaine.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  message!: string;
}

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post('relance')
  @ApiOperation({ summary: "Relancer le promoteur d'une visite non effectuée (notification in-app / mobile)" })
  relance(@Body() dto: RelanceDto, @CurrentUser() user: { id: string }) {
    return this.notifications.relancerVisite(dto.planningId, user.id);
  }

  @Post('relance-membre')
  @UseGuards(RolesGuard)
  @Roles(Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN)
  @ApiOperation({ summary: "Relancer un membre de MON équipe (DR → ses CS ; Direction/ADMIN → tous)" })
  relanceMembre(@Body() dto: RelanceMembreDto, @CurrentUser() user: { id: string; role: string }) {
    return this.notifications.relancerMembre(dto.userId, dto.message, user);
  }

  @Get('me')
  @ApiOperation({ summary: "Boîte de réception de l'utilisateur courant (20 dernières + non lues)" })
  me(@CurrentUser() user: { id: string }) {
    return this.notifications.boite(user.id);
  }

  @Patch(':id/lu')
  @ApiOperation({ summary: 'Marquer UNE notification comme lue' })
  lu(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: { id: string }) {
    return this.notifications.marquerLu(id, user.id);
  }

  @Post('lu-tout')
  @ApiOperation({ summary: 'Tout marquer comme lu' })
  luTout(@CurrentUser() user: { id: string }) {
    return this.notifications.toutMarquerLu(user.id);
  }
}
