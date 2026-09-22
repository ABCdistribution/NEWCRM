import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';

class RelanceDto {
  @ApiProperty({ description: 'UUID de la visite planifiée à relancer' })
  @IsUUID()
  planningId!: string;
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

  @Get('me')
  @ApiOperation({ summary: "Boîte de réception de l'utilisateur courant (20 dernières + non lues)" })
  me(@CurrentUser() user: { id: string }) {
    return this.notifications.boite(user.id);
  }

  @Post('lu-tout')
  @ApiOperation({ summary: 'Tout marquer comme lu' })
  luTout(@CurrentUser() user: { id: string }) {
    return this.notifications.toutMarquerLu(user.id);
  }
}
