import { Controller, Get, Param, ParseUUIDPipe, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { typeImage } from '../auth/annuaire-photos.service';

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
  @ApiOperation({ summary: "Photo (JPEG ou PNG) d'un utilisateur (404 si absente)" })
  async photo(@Param('id', ParseUUIDPipe) id: string, @Res() res: Response) {
    const user = await this.prisma.user.findUnique({ where: { id }, select: { photo: true } });
    if (!user?.photo) {
      res.status(404).end();
      return;
    }
    const buf = Buffer.isBuffer(user.photo) ? user.photo : Buffer.from(user.photo);
    // Type d'après le contenu : l'AD donne du JPEG, l'annuaire a aussi des PNG.
    res.setHeader('Content-Type', typeImage(buf) ?? 'image/jpeg');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(buf);
  }
}
