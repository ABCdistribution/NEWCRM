import { Module } from '@nestjs/common';
import { CentralesController } from './centrales.controller';
import { CentralesService } from './centrales.service';

@Module({
  controllers: [CentralesController],
  providers: [CentralesService],
})
export class CentralesModule {}
