import { Controller, Get, Param, ParseUUIDPipe, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Photo d'un utilisateur. Accessible à tout utilisateur authentifié (pour afficher
 * les avatars), contrairement au reste de UsersController réservé ADMIN.
 */
@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UserPhotoController {
  constructor(private readonly prisma: PrismaService) {}

  @Get(':id/photo')
  @ApiOperation({ summary: "Photo JPEG d'un utilisateur (404 si absente)" })
  async photo(@Param('id', ParseUUIDPipe) id: string, @Res() res: Response) {
    const user = await this.prisma.user.findUnique({ where: { id }, select: { photo: true } });
    if (!user?.photo) {
      res.status(404).end();
      return;
    }
    const buf = Buffer.isBuffer(user.photo) ? user.photo : Buffer.from(user.photo);
    res.setHeader('Content-Type', 'image/jpeg');
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(buf);
  }
}
