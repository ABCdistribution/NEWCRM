import { Module } from '@nestjs/common';
import { ProspectsController } from './prospects.controller';
import { ProspectsService } from './prospects.service';
import { OpportunitesController } from './opportunites.controller';
import { OpportunitesService } from './opportunites.service';

/** Prospection & pipeline (module Helios) : prospects, Kanban, opportunités, conversion en client. */
@Module({
  controllers: [ProspectsController, OpportunitesController],
  providers: [ProspectsService, OpportunitesService],
  exports: [ProspectsService],
})
export class ProspectionModule {}
