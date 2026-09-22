import { Module } from '@nestjs/common';
import { CommandesController } from './commandes.controller';
import { CommandesService } from './commandes.service';
import { CommandesApkService } from './commandes-apk.service';

@Module({
  controllers: [CommandesController],
  providers: [CommandesService, CommandesApkService],
})
export class CommandesModule {}
