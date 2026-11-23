import { Module } from '@nestjs/common';
import { ProduitsIndispensablesController } from './produits-indispensables.controller';
import { ProduitsIndispensablesService } from './produits-indispensables.service';

@Module({
  controllers: [ProduitsIndispensablesController],
  providers: [ProduitsIndispensablesService],
})
export class ProduitsIndispensablesModule {}
