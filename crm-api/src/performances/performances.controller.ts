import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { PerformancesService } from './performances.service';

@ApiTags('performances')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('performances')
export class PerformancesController {
  constructor(private readonly performances: PerformancesService) {}

  @Get('me')
  @ApiOperation({ summary: "Performances personnelles du commercial connecté (mois donné, défaut : mois courant)" })
  @ApiQuery({ name: 'annee', required: false, type: Number })
  @ApiQuery({ name: 'mois', required: false, type: Number })
  me(
    @CurrentUser() user: { id: string; idRepr: string | null },
    @Query('annee') annee?: string,
    @Query('mois') mois?: string,
  ) {
    const now = new Date();
    const a = Number(annee) || now.getFullYear();
    const m = Math.min(12, Math.max(1, Number(mois) || now.getMonth() + 1));
    return this.performances.forUser(user, a, m);
  }
}
