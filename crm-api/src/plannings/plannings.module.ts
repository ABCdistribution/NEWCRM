import { Module } from '@nestjs/common';
import { PlanningsController, PlannificationsController } from './plannings.controller';
import { TourneesController } from './tournees.controller';
import { IcalController } from './ical.controller';
import { PlanningsService } from './plannings.service';

@Module({
  controllers: [PlanningsController, PlannificationsController, TourneesController, IcalController],
  providers: [PlanningsService],
  exports: [PlanningsService], // le dashboard matérialise les occurrences du jour
})
export class PlanningsModule {}
