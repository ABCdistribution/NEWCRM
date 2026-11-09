import { Module } from '@nestjs/common';
import { PlanningsModule } from '../plannings/plannings.module';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';
import { CarteService } from './carte.service';

@Module({
  imports: [PlanningsModule], // matérialisation des visites récurrentes du jour
  controllers: [DashboardController],
  providers: [DashboardService, CarteService],
})
export class DashboardModule {}
