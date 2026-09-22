import { Module } from '@nestjs/common';
import { VisitesController } from './visites.controller';
import { VisitesService } from './visites.service';

@Module({
  controllers: [VisitesController],
  providers: [VisitesService],
})
export class VisitesModule {}
