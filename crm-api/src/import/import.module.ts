import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ImportController } from './import.controller';
import { ImportService } from './import.service';
import { MinosImportProcessor } from './minos-import.processor';

@Module({
  imports: [BullModule.registerQueue({ name: 'minos-import' })],
  controllers: [ImportController],
  providers: [ImportService, MinosImportProcessor],
})
export class ImportModule {}
