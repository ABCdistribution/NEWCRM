import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** Lundi (minuit local) de la semaine contenant `d`. */
function mondayOf(d: Date): Date {
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return monday;
}

/** yyyy-mm-dd (composantes locales). */
function isoDay(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

@Injectable()
export class PlanningsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Matérialise les occurrences des règles de récurrence actives du promoteur
   * sur [debut, fin). Idempotent : ne crée jamais deux visites du même magasin
   * le même jour (règle ou saisie manuelle confondues).
   */
  async ensureOccurrences(promoteurId: string, debut: Date, fin: Date): Promise<void> {
    const regles = await this.prisma.plannification.findMany({
      where: {
        promoteurId,
        deletedAt: null,
        dateDebut: { lt: fin },
        OR: [{ dateFin: null }, { dateFin: { gte: debut } }],
      },
      select: { id: true, clientId: true, jours: true, recurrence: true, dateDebut: true, dateFin: true },
    });
    if (regles.length === 0) return;

    // Visites déjà présentes sur la période (clé client|jour), toutes origines confondues.
    const existants = await this.prisma.planning.findMany({
      where: { promoteurId, deletedAt: null, datePassage: { gte: debut, lt: fin } },
      select: { clientId: true, datePassage: true },
    });
    const occupe = new Set(existants.map((p) => `${p.clientId}|${isoDay(new Date(p.datePassage))}`));

    const aCreer: { promoteurId: string; clientId: string; datePassage: Date; plannificationId: string }[] = [];
    const WEEK_MS = 7 * 24 * 3600 * 1000;
    // Bornes en jours calendaires (évite les décalages UTC/local sur les minuits).
    const debutIso = isoDay(new Date(debut));
    const finIso = isoDay(new Date(fin));

    for (const regle of regles) {
      const joursSet = new Set(
        regle.jours
          .split(',')
          .map((s) => Number(s.trim()))
          .filter((n) => n >= 1 && n <= 6),
      );
      if (joursSet.size === 0) continue;

      const ancre = mondayOf(new Date(regle.dateDebut));
      // Parcourt les semaines couvrant la période demandée.
      for (let lundi = mondayOf(new Date(debut)); lundi < fin; lundi = new Date(lundi.getTime() + WEEK_MS)) {
        const ecartSemaines = Math.round((lundi.getTime() - ancre.getTime()) / WEEK_MS);
        if (ecartSemaines < 0 || ecartSemaines % regle.recurrence !== 0) continue;

        for (const jour of joursSet) {
          const date = new Date(lundi);
          date.setDate(date.getDate() + (jour - 1));
          const dayIso = isoDay(date);
          // Comparaisons en jours calendaires (yyyy-mm-dd, ordre lexicographique).
          if (dayIso < debutIso || dayIso >= finIso) continue;
          if (dayIso < isoDay(new Date(regle.dateDebut))) continue;
          if (regle.dateFin && dayIso > isoDay(new Date(regle.dateFin))) continue;

          const cle = `${regle.clientId}|${dayIso}`;
          if (occupe.has(cle)) continue;
          occupe.add(cle);
          aCreer.push({
            promoteurId,
            clientId: regle.clientId,
            datePassage: new Date(isoDay(date)), // minuit UTC, cohérent avec la saisie manuelle
            plannificationId: regle.id,
          });
        }
      }
    }

    if (aCreer.length > 0) {
      await this.prisma.planning.createMany({ data: aCreer });
    }
  }

  /** Visites planifiées d'un promoteur sur une période (bornes ISO, fin exclue). */
  /** Visites planifiées à venir (non faites) d'un magasin — pour le suivi encadrement. */
  async findAVenirPourClient(clientId: string) {
    const aujourdhui = new Date();
    aujourdhui.setHours(0, 0, 0, 0);
    return this.prisma.planning.findMany({
      where: { clientId, deletedAt: null, fait: false, datePassage: { gte: aujourdhui } },
      orderBy: { datePassage: 'asc' },
      take: 10,
      select: {
        id: true,
        datePassage: true,
        promoteur: { select: { id: true, displayName: true } },
      },
    });
  }

  async findPeriode(promoteurId: string, debut: Date, fin: Date) {
    await this.ensureOccurrences(promoteurId, debut, fin);
    return this.prisma.planning.findMany({
      where: { promoteurId, deletedAt: null, datePassage: { gte: debut, lt: fin } },
      orderBy: { datePassage: 'asc' },
      select: {
        id: true,
        datePassage: true,
        fait: true,
        raison: true,
        plannificationId: true,
        client: { select: { id: true, codeAs400: true, enseigne: true, ville: true, niveauClass: true } },
      },
    });
  }

  /** Planifie une visite ponctuelle (direction). Refuse le doublon même client / même jour. */
  async create(promoteurId: string, clientId: string, datePassage: Date) {
    if (Number.isNaN(datePassage.getTime())) {
      throw new BadRequestException('Date invalide');
    }
    const [promoteur, client] = await Promise.all([
      this.prisma.user.findFirst({ where: { id: promoteurId, isActive: true } }),
      this.prisma.client.findFirst({ where: { id: clientId, deletedAt: null } }),
    ]);
    if (!promoteur) throw new NotFoundException('Promoteur introuvable');
    if (!client) throw new NotFoundException('Client introuvable');

    await this.verifieDoublon(promoteurId, clientId, datePassage);

    return this.prisma.planning.create({
      data: { promoteurId, clientId, datePassage },
      select: {
        id: true,
        datePassage: true,
        fait: true,
        client: { select: { id: true, enseigne: true, ville: true, niveauClass: true } },
      },
    });
  }

  /** Déplace une visite planifiée vers une autre date (même garde anti-doublon). */
  async move(id: string, datePassage: Date) {
    if (Number.isNaN(datePassage.getTime())) {
      throw new BadRequestException('Date invalide');
    }
    const planning = await this.prisma.planning.findFirst({ where: { id, deletedAt: null } });
    if (!planning) throw new NotFoundException('Visite planifiée introuvable');
    if (planning.fait) throw new ConflictException('Visite déjà effectuée — non déplaçable');

    await this.verifieDoublon(planning.promoteurId, planning.clientId, datePassage, id);

    return this.prisma.planning.update({
      where: { id },
      data: { datePassage },
      select: { id: true, datePassage: true },
    });
  }

  /** Retire une visite planifiée (soft delete). */
  async remove(id: string) {
    const planning = await this.prisma.planning.findFirst({ where: { id, deletedAt: null } });
    if (!planning) throw new NotFoundException('Visite planifiée introuvable');
    await this.prisma.planning.update({ where: { id }, data: { deletedAt: new Date() } });
    return { id, deleted: true };
  }

  private async verifieDoublon(
    promoteurId: string,
    clientId: string,
    datePassage: Date,
    exceptId?: string,
  ): Promise<void> {
    const jourDebut = new Date(datePassage.getFullYear(), datePassage.getMonth(), datePassage.getDate());
    const jourFin = new Date(jourDebut);
    jourFin.setDate(jourFin.getDate() + 1);
    const doublon = await this.prisma.planning.findFirst({
      where: {
        ...(exceptId ? { id: { not: exceptId } } : {}),
        promoteurId,
        clientId,
        deletedAt: null,
        datePassage: { gte: jourDebut, lt: jourFin },
      },
    });
    if (doublon) {
      throw new ConflictException('Ce magasin est déjà planifié ce jour-là pour ce promoteur');
    }
  }

  // --- Règles de récurrence (plannifications) ----------------------------

  /** Règles actives d'un promoteur, avec le magasin. */
  listRegles(promoteurId: string) {
    return this.prisma.plannification.findMany({
      where: { promoteurId, deletedAt: null },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        jours: true,
        recurrence: true,
        dateDebut: true,
        dateFin: true,
        client: { select: { id: true, enseigne: true, ville: true, niveauClass: true } },
      },
    });
  }

  /** Crée une règle de récurrence (magasin × jours × fréquence). */
  async createRegle(
    promoteurId: string,
    clientId: string,
    jours: number[],
    recurrence: number,
    dateDebut: Date,
  ) {
    const joursValides = [...new Set(jours)].filter((j) => j >= 1 && j <= 6).sort();
    if (joursValides.length === 0) throw new BadRequestException('Au moins un jour de semaine requis');
    if (!(recurrence >= 1 && recurrence <= 8)) throw new BadRequestException('Fréquence invalide (1 à 8 semaines)');
    if (Number.isNaN(dateDebut.getTime())) throw new BadRequestException('Date de début invalide');

    const [promoteur, client] = await Promise.all([
      this.prisma.user.findFirst({ where: { id: promoteurId, isActive: true } }),
      this.prisma.client.findFirst({ where: { id: clientId, deletedAt: null } }),
    ]);
    if (!promoteur) throw new NotFoundException('Promoteur introuvable');
    if (!client) throw new NotFoundException('Client introuvable');

    const existante = await this.prisma.plannification.findFirst({
      where: { promoteurId, clientId, deletedAt: null },
    });
    if (existante) {
      throw new ConflictException('Une récurrence existe déjà pour ce magasin (la supprimer avant d\'en créer une autre)');
    }

    return this.prisma.plannification.create({
      data: { promoteurId, clientId, jours: joursValides.join(','), recurrence, dateDebut },
      select: { id: true, jours: true, recurrence: true, dateDebut: true },
    });
  }

  /** Supprime une règle + ses occurrences futures non réalisées. */
  async removeRegle(id: string) {
    const regle = await this.prisma.plannification.findFirst({ where: { id, deletedAt: null } });
    if (!regle) throw new NotFoundException('Récurrence introuvable');

    const aujourdhui = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate());
    await this.prisma.$transaction([
      this.prisma.plannification.update({ where: { id }, data: { deletedAt: new Date() } }),
      this.prisma.planning.updateMany({
        where: { plannificationId: id, fait: false, deletedAt: null, datePassage: { gte: aujourdhui } },
        data: { deletedAt: new Date() },
      }),
    ]);
    return { id, deleted: true };
  }
}
