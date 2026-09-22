import { Controller, Get, Header, NotFoundException, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';

/** Jeton iCal d'un utilisateur : HMAC de son id (aucun état en base). */
export function icalToken(userId: string): string {
  return createHmac('sha256', `${process.env.JWT_SECRET ?? ''}:ical`).update(userId).digest('hex').slice(0, 32);
}

function echapper(texte: string): string {
  return texte.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

function horodatage(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}T${p(d.getHours())}${p(d.getMinutes())}00`;
}

/**
 * Flux iCalendar (ICS) du planning d'activité — SANS authentification JWT :
 * Outlook s'abonne à l'URL (jeton HMAC personnel dans le chemin) et le
 * calendrier se met à jour tout seul à chaque rafraîchissement.
 */
@ApiTags('tournees')
@Controller('tournees')
export class IcalController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('ical/:userId/:token')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="planning-activite.ics"')
  @ApiOperation({ summary: "Flux ICS du planning d'activité (abonnement Outlook) — jeton personnel requis" })
  async ical(@Param('userId', ParseUUIDPipe) userId: string, @Param('token') token: string) {
    const attendu = icalToken(userId);
    const recu = String(token ?? '');
    if (
      recu.length !== attendu.length ||
      !timingSafeEqual(Buffer.from(recu), Buffer.from(attendu))
    ) {
      throw new NotFoundException('Calendrier introuvable');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { displayName: true } });
    if (!user) throw new NotFoundException('Calendrier introuvable');

    // Fenêtre glissante : 4 semaines passées → 12 semaines à venir.
    const debut = new Date();
    debut.setDate(debut.getDate() - 28);
    const fin = new Date();
    fin.setDate(fin.getDate() + 84);

    const etapes = await this.prisma.tourneeEtape.findMany({
      where: { userId, deletedAt: null, datePassage: { gte: debut, lt: fin } },
      orderBy: { datePassage: 'asc' },
      select: {
        id: true,
        datePassage: true,
        fait: true,
        note: true,
        adm: true,
        rdv: true,
        accompagnement: true,
        soireeEtape: true,
        soireeLieu: true,
        soireeAdresse: true,
        updatedAt: true,
        client: { select: { enseigne: true, raisonSociale: true, adresse1: true, codePostal: true, ville: true } },
        prospect: { select: { enseigne: true, adresse1: true, codePostal: true, ville: true } },
      },
    });

    const lignes: string[] = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ABC Distribution//CRM Helios//FR',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      `X-WR-CALNAME:${echapper(`Planning d'activité — ${user.displayName}`)}`,
      'X-PUBLISHED-TTL:PT1H',
    ];

    for (const e of etapes) {
      const cible = e.client ?? e.prospect;
      const nom = e.adm
        ? 'ADM — administratif'
        : (cible?.enseigne || (e.client?.raisonSociale ?? '') || 'Visite').trim();
      const prefixe = e.rdv ? '[RDV] ' : '';
      const type = e.adm ? '' : e.prospect ? ' (prospection)' : e.accompagnement ? ' (accompagnement promoteur)' : '';
      const adresse = cible
        ? [cible.adresse1, cible.codePostal, cible.ville].map((x) => x?.trim()).filter(Boolean).join(', ')
        : '';
      const description = [
        e.fait ? 'Visite effectuée.' : null,
        e.note ? `Observations : ${e.note}` : null,
        e.soireeEtape
          ? `Soirée étape${e.soireeLieu ? ` — ${e.soireeLieu}` : ''}${e.soireeAdresse ? ` (${e.soireeAdresse})` : ''}`
          : null,
      ]
        .filter(Boolean)
        .join('\n');

      const d = e.datePassage;
      const avecHeure = d.getHours() !== 0 || d.getMinutes() !== 0;
      lignes.push('BEGIN:VEVENT');
      lignes.push(`UID:etape-${e.id}@crm-helios.abc`);
      lignes.push(`DTSTAMP:${horodatage(e.updatedAt)}`);
      if (avecHeure) {
        const finEvt = new Date(d.getTime() + 60 * 6e4); // créneau d'1 h par défaut
        lignes.push(`DTSTART:${horodatage(d)}`);
        lignes.push(`DTEND:${horodatage(finEvt)}`);
      } else {
        const p = (n: number) => String(n).padStart(2, '0');
        const jour = `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}`;
        lignes.push(`DTSTART;VALUE=DATE:${jour}`);
      }
      lignes.push(`SUMMARY:${echapper(`${prefixe}${nom}${type}`)}`);
      if (adresse) lignes.push(`LOCATION:${echapper(adresse)}`);
      if (description) lignes.push(`DESCRIPTION:${echapper(description)}`);
      lignes.push(`STATUS:${e.fait ? 'CONFIRMED' : 'TENTATIVE'}`);
      lignes.push('END:VEVENT');
    }

    lignes.push('END:VCALENDAR');
    return lignes.join('\r\n');
  }
}
