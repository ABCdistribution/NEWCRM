import { Module } from '@nestjs/common';
import { RaisonsAbsenceController } from './raisons-absence.controller';
import { RaisonsAbsenceService } from './raisons-absence.service';

@Module({
  controllers: [RaisonsAbsenceController],
  providers: [RaisonsAbsenceService],
})
export class RaisonsAbsenceModule {}
