import { Module } from '@nestjs/common';
import { ObjectifsController } from './objectifs.controller';
import { ObjectifsService } from './objectifs.service';

@Module({
  controllers: [ObjectifsController],
  providers: [ObjectifsService],
})
export class ObjectifsModule {}
