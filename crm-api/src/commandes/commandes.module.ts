import { Module } from '@nestjs/common';
import { MailModule } from '../mail/mail.module';
import { CommandesController } from './commandes.controller';
import { CommandesService } from './commandes.service';
import { CommandesApkService } from './commandes-apk.service';

@Module({
  imports: [MailModule],
  controllers: [CommandesController],
  providers: [CommandesService, CommandesApkService],
})
export class CommandesModule {}
