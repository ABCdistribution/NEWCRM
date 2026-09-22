import { InjectQueue } from '@nestjs/bullmq';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Queue } from 'bullmq';
import { basename } from 'node:path';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ImportService {
  constructor(
    @InjectQueue('minos-import') private readonly queue: Queue,
    private readonly prisma: PrismaService,
  ) {}

  /** Crée un log d'import et met le fichier en file d'attente (asynchrone). */
  private async enqueue(type: 'client' | 'article' | 'centrale', filePath: string) {
    const fileName = basename(filePath);
    // Garde-fou : un fichier importé avec le mauvais mapping crée des données
    // corrompues (vécu : un ARB parti dans l'import clients). Le préfixe fait foi.
    const prefixe = fileName.toUpperCase().slice(0, 3);
    const attendu = { client: 'CLI', article: 'ART', centrale: 'ARB' }[type];
    if (prefixe !== attendu) {
      throw new BadRequestException(
        `Le fichier « ${fileName} » ne correspond pas à l'import ${type} (préfixe ${attendu}_* attendu).`,
      );
    }
    const log = await this.prisma.erpImportLog.create({
      data: { fileName, source: 'MINOS', status: 'PENDING' },
    });
    const job = await this.queue.add(type, { logId: log.id, filePath });
    return { logId: log.id, jobId: job.id, fileName, status: 'PENDING' };
  }

  enqueueClients(filePath: string) {
    return this.enqueue('client', filePath);
  }

  enqueueArticles(filePath: string) {
    return this.enqueue('article', filePath);
  }

  enqueueCentrales(filePath: string) {
    return this.enqueue('centrale', filePath);
  }

  async getLog(id: string) {
    const log = await this.prisma.erpImportLog.findUnique({ where: { id } });
    if (!log) throw new NotFoundException('Import introuvable');
    return log;
  }

  /** Journal des imports, du plus récent au plus ancien. */
  listLogs(limit = 50) {
    return this.prisma.erpImportLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 200),
    });
  }
}
