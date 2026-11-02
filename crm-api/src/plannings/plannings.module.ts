import { Module } from '@nestjs/common';
import { PlanningsController, PlannificationsController } from './plannings.controller';
import { TourneesController } from './tournees.controller';
import { RapportsController } from './rapports.controller';
import { IcalController } from './ical.controller';
import { PlanningsService } from './plannings.service';
import { RapportsService } from './rapports.service';

@Module({
  controllers: [PlanningsController, PlannificationsController, TourneesController, RapportsController, IcalController],
  providers: [PlanningsService, RapportsService],
  exports: [PlanningsService], // le dashboard matérialise les occurrences du jour
})
export class PlanningsModule {}
