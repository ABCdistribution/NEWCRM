import { Body, Controller, Get, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Role } from '@crm/database';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ImportService } from './import.service';
import { TriggerImportDto } from './dto/trigger-import.dto';

@ApiTags('import')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('import/minos')
export class ImportController {
  constructor(private readonly service: ImportService) {}

  @Post('clients')
  @ApiOperation({ summary: 'Lance l’import Minos des clients (asynchrone via BullMQ)' })
  triggerClients(@Body() dto: TriggerImportDto) {
    return this.service.enqueueClients(dto.filePath);
  }

  @Post('articles')
  @ApiOperation({ summary: 'Lance l’import Minos des articles (asynchrone via BullMQ)' })
  triggerArticles(@Body() dto: TriggerImportDto) {
    return this.service.enqueueArticles(dto.filePath);
  }

  @Post('centrales')
  @ApiOperation({ summary: "Lance l'import Minos de l'arborescence d'achat ARB (centrales + rattachement clients)" })
  triggerCentrales(@Body() dto: TriggerImportDto) {
    return this.service.enqueueCentrales(dto.filePath);
  }

  @Get('fichiers')
  @ApiOperation({ summary: "Fichiers présents dans la zone de dépôt AS400 (IMPORT_DIR), les plus récents en premier" })
  async listFichiers() {
    const racine = process.env.IMPORT_DIR ?? '/imports';
    const fichiers: { nom: string; chemin: string; taille: number; modifieLe: string }[] = [];
    const scan = async (dir: string) => {
      let entries: string[];
      try {
        entries = await readdir(dir);
      } catch {
        return; // zone non montée / vide — pas une erreur
      }
      for (const nom of entries) {
        const chemin = join(dir, nom);
        // Les .TMP sont des dépôts techniques en cours (commandes du jour) — hors périmètre.
        if (nom.toUpperCase().endsWith('.TMP')) continue;
        try {
          const s = await stat(chemin);
          if (s.isDirectory()) await scan(chemin);
          else fichiers.push({ nom, chemin, taille: s.size, modifieLe: s.mtime.toISOString() });
        } catch {
          // fichier disparu entre readdir et stat — ignorer
        }
      }
    };
    await scan(racine);
    fichiers.sort((a, b) => b.modifieLe.localeCompare(a.modifieLe));
    return { racine, fichiers: fichiers.slice(0, 100) };
  }

  @Get('logs')
  @ApiOperation({ summary: 'Journal des imports (les plus récents en premier)' })
  listLogs() {
    return this.service.listLogs();
  }

  @Get('logs/:id')
  @ApiOperation({ summary: 'État / résultat d’un import' })
  getLog(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.getLog(id);
  }
}
