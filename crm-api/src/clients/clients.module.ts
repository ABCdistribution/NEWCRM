import { Module } from '@nestjs/common';
import { ClientsController, PeriodicitesController } from './clients.controller';
import { ClientsService } from './clients.service';

@Module({
  controllers: [ClientsController, PeriodicitesController],
  providers: [ClientsService],
})
export class ClientsModule {}
