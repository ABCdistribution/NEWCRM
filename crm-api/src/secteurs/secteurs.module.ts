import { Module } from '@nestjs/common';
import { SecteursController } from './secteurs.controller';
import { SecteursService } from './secteurs.service';

@Module({
  controllers: [SecteursController],
  providers: [SecteursService],
})
export class SecteursModule {}
