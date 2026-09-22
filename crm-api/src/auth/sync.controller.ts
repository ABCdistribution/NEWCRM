import { Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@crm/database';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from './decorators/roles.decorator';
import { AdSyncService } from './ad-sync.service';

@ApiTags('auth')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('sync')
export class SyncController {
  constructor(private readonly adSync: AdSyncService) {}

  @Post('ad')
  @ApiOperation({
    summary:
      "Synchronise la force de vente française depuis l'AD : provisionne promoteurs/chefs/directeurs, rattache régions et hiérarchie (ADMIN)",
  })
  syncAd() {
    return this.adSync.syncForceDeVente();
  }
}
