import { Module } from '@nestjs/common';
import { ProspectionModule } from '../prospection/prospection.module';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

@Module({
  imports: [ProspectionModule],
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
