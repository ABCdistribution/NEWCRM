import { Module } from '@nestjs/common';
import { PemClientsController, PemController } from './pem.controller';
import { PemProgrammationService } from './pem-programmation.service';
import { PemService } from './pem.service';

@Module({
  controllers: [PemController, PemClientsController],
  providers: [PemService, PemProgrammationService],
})
export class PemModule {}
