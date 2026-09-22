import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import { PrismaService } from '../prisma/prisma.service';
import { parseFixedWidth } from './fixed-width-parser';
import { clientFieldSpec } from './mappings/client.mapping';
import { clientRowSchema, toMinosClientData } from './mappings/client.schema';
import { articleFieldSpec } from './mappings/article.mapping';
import { articleRowSchema, toMinosArticleData } from './mappings/article.schema';
import { centraleFieldSpec } from './mappings/centrale.mapping';
import { centraleRowSchema } from './mappings/centrale.schema';

interface MinosJobData {
  logId: string;
  filePath: string;
}

/** Type d'import à plat (upsert par codeAs400) — l'arborescence ARB reste à part. */
type TypeImport = 'client' | 'article';

/**
 * Worker BullMQ d'import Minos.
 * Optimisé : streaming ligne par ligne, validation Zod, upsert par lots.
 * L'upsert ne met à jour QUE les champs Minos → les champs CRM ne sont jamais écrasés
 * (fin du vidage/réinsertion nocturne du legacy).
 */
@Processor('minos-import')
export class MinosImportProcessor extends WorkerHost {
  private readonly logger = new Logger(MinosImportProcessor.name);
  private readonly batchSize = 500;

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job<MinosJobData>): Promise<{ total: number; ok: number; failed: number }> {
    // L'arborescence d'achat (ARB) a sa propre logique hiérarchique.
    if (job.name === 'centrale') return this.processCentrales(job);
    const { logId, filePath } = job.data;
    await this.prisma.erpImportLog.update({
      where: { id: logId },
      data: { status: 'PROCESSING', startedAt: new Date() },
    });

    // Le nom du job (« client » / « article ») sélectionne le mapping et la table cible.
    const type = (job.name as TypeImport) === 'article' ? 'article' : 'client';

    let total = 0;
    let ok = 0;
    let failed = 0;
    const errors: string[] = [];
    let batch: (ReturnType<typeof toMinosClientData> | ReturnType<typeof toMinosArticleData>)[] = [];

    const flush = async (): Promise<void> => {
      if (batch.length === 0) return;
      const rows = batch;
      batch = [];
      // Upsert par codeAs400 : les champs Minos uniquement — les champs CRM
      // (actif, niveauClass, stock, détails…) ne sont jamais écrasés.
      if (type === 'article') {
        await this.prisma.$transaction(
          (rows as ReturnType<typeof toMinosArticleData>[]).map((data) =>
            this.prisma.article.upsert({
              where: { codeAs400: data.codeAs400 },
              create: data,
              update: data,
            }),
          ),
        );
      } else {
        await this.prisma.$transaction(
          (rows as ReturnType<typeof toMinosClientData>[]).map((data) =>
            this.prisma.client.upsert({
              where: { codeAs400: data.codeAs400 },
              create: data,
              update: data,
            }),
          ),
        );
      }
    };

    try {
      // AS400 : fichiers encodés en latin1 (ISO-8859-1) — accents français corrects.
      const rl = createInterface({
        input: createReadStream(filePath, { encoding: 'latin1' }),
        crlfDelay: Infinity,
      });

      for await (const line of rl) {
        if (line.trim().length === 0) continue;
        total++;
        if (type === 'article') {
          const raw = parseFixedWidth(line, articleFieldSpec);
          const parsed = articleRowSchema.safeParse(raw);
          if (!parsed.success) {
            failed++;
            if (errors.length < 50) {
              errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'ligne invalide'}`);
            }
            continue;
          }
          batch.push(toMinosArticleData(parsed.data));
        } else {
          const raw = parseFixedWidth(line, clientFieldSpec);
          const parsed = clientRowSchema.safeParse(raw);
          if (!parsed.success) {
            failed++;
            if (errors.length < 50) {
              errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'ligne invalide'}`);
            }
            continue;
          }
          batch.push(toMinosClientData(parsed.data));
        }
        ok++;
        if (batch.length >= this.batchSize) await flush();
        if (total % 5000 === 0) await job.updateProgress(total);
      }
      await flush();
    } catch (err) {
      await this.prisma.erpImportLog.update({
        where: { id: logId },
        data: {
          status: 'FAILED',
          rowsTotal: total,
          rowsOk: ok,
          rowsFailed: failed,
          finishedAt: new Date(),
          errorMessage: (err as Error).message,
        },
      });
      throw err;
    }

    const status = ok === 0 && failed > 0 ? 'FAILED' : 'SUCCESS';
    await this.prisma.erpImportLog.update({
      where: { id: logId },
      data: {
        status,
        rowsTotal: total,
        rowsOk: ok,
        rowsFailed: failed,
        finishedAt: new Date(),
        errorMessage: errors.length ? errors.join('\n') : null,
      },
    });
    this.logger.log(`Import ${logId} terminé : ${ok}/${total} OK, ${failed} échec(s)`);
    return { total, ok, failed };
  }

  /**
   * Import ARB : construit l'arbre centrale → sous-centrale → sous-sous-centrale
   * (auto-référencé, le parent du 1er vu fait foi) et rattache chaque client à sa
   * feuille. Porté du script CLI import-centrales.cjs.
   */
  private async processCentrales(job: Job<MinosJobData>): Promise<{ total: number; ok: number; failed: number }> {
    const { logId, filePath } = job.data;
    await this.prisma.erpImportLog.update({
      where: { id: logId },
      data: { status: 'PROCESSING', startedAt: new Date() },
    });

    const cleanCode = (v?: string): string | null => {
      const t = v?.trim();
      return !t || /^0+$/.test(t) || /^\*+$/.test(t) ? null : t;
    };

    const cache = new Map<string, string>(); // code -> id
    const ensureCentrale = async (code?: string, nom?: string, parentId?: string | null): Promise<string | null> => {
      const c = cleanCode(code);
      if (!c) return null;
      const existant = cache.get(c);
      if (existant) return existant;
      const rec = await this.prisma.centrale.upsert({
        where: { code: c },
        create: { code: c, nom: nom?.trim() || c, parentId: parentId ?? null },
        update: { nom: nom?.trim() || c }, // le parent du premier passage fait foi
      });
      cache.set(c, rec.id);
      return rec.id;
    };

    let total = 0;
    let ok = 0;
    let failed = 0;
    let lies = 0;
    let introuvables = 0;
    const errors: string[] = [];
    let batch: { codeAs400: string; centraleId: string }[] = [];

    const flush = async (): Promise<void> => {
      if (batch.length === 0) return;
      const rows = batch;
      batch = [];
      const results = await this.prisma.$transaction(
        rows.map((r) =>
          this.prisma.client.updateMany({ where: { codeAs400: r.codeAs400 }, data: { centraleId: r.centraleId } }),
        ),
      );
      for (const res of results) {
        if (res.count > 0) lies++;
        else introuvables++;
      }
    };

    try {
      const rl = createInterface({
        input: createReadStream(filePath, { encoding: 'latin1' }),
        crlfDelay: Infinity,
      });
      for await (const line of rl) {
        if (line.trim().length === 0) continue;
        total++;
        const parsed = centraleRowSchema.safeParse(parseFixedWidth(line, centraleFieldSpec));
        if (!parsed.success) {
          failed++;
          if (errors.length < 50) errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'ligne invalide'}`);
          continue;
        }
        const row = parsed.data;
        const centraleId = await ensureCentrale(row.codeCentrale, row.nomCentrale, null);
        const sCentraleId = await ensureCentrale(row.codeSCentrale, row.nomSCentrale, centraleId);
        const ssCentraleId = await ensureCentrale(row.codeSsCentrale, row.nomSsCentrale, sCentraleId);
        ok++;
        const feuilleId = ssCentraleId ?? sCentraleId ?? centraleId;
        if (feuilleId) {
          batch.push({ codeAs400: row.codeClient, centraleId: feuilleId });
          if (batch.length >= this.batchSize) await flush();
        }
        if (total % 5000 === 0) await job.updateProgress(total);
      }
      await flush();
    } catch (err) {
      await this.prisma.erpImportLog.update({
        where: { id: logId },
        data: {
          status: 'FAILED',
          rowsTotal: total,
          rowsOk: ok,
          rowsFailed: failed,
          finishedAt: new Date(),
          errorMessage: (err as Error).message,
        },
      });
      throw err;
    }

    const status = ok === 0 && failed > 0 ? 'FAILED' : 'SUCCESS';
    await this.prisma.erpImportLog.update({
      where: { id: logId },
      data: {
        status,
        rowsTotal: total,
        rowsOk: ok,
        rowsFailed: failed,
        finishedAt: new Date(),
        errorMessage: errors.length ? errors.join('\n') : null,
      },
    });
    this.logger.log(
      `Import ARB ${logId} terminé : ${ok}/${total} OK, ${failed} échec(s) — ` +
        `${cache.size} centrales, ${lies} clients rattachés, ${introuvables} introuvables`,
    );
    return { total, ok, failed };
  }
}
