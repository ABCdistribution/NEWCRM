import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ArticlesService } from './articles.service';
import { QueryArticlesDto } from './dto/query-articles.dto';

@ApiTags('articles')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('articles')
export class ArticlesController {
  constructor(private readonly articles: ArticlesService) {}

  @Get()
  @ApiOperation({ summary: 'Liste paginée des articles (recherche via ?search=)' })
  findAll(@Query() query: QueryArticlesDto) {
    return this.articles.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: "Détail d'un article" })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.articles.findOne(id);
  }
}
