// « Clients passés inactifs » (modal de la page /clients) : types, lecture défensive de la réponse de l'API, libellés et
// export CSV. Fonctions pures, sans réseau : importables côté serveur comme côté client, testées à part.
import type { Role } from './api';

/** Un passage en inactif effectué depuis le CRM. */
export type ClientPasseInactif = {
  id: string;
  enseigne: string;
  codeAs400: string;
  ville: string | null;
  /** Date et heure du passage en inactif (ISO). */
  date: string;
  modifiePar: string | null;
  /** Directeur régional du client. */
  dr: string | null;
  /** Le client n'apparaît plus dans les fichiers de l'AS400. */
  retireAs400: boolean;
  /** Date d'envoi à l'ADV (ISO), absente tant que rien n'est parti. */
  envoyeAdvLe: string | null;
};

export type PassesInactifs = {
  /** false tant que l'API n'enregistre pas les passages en inactif (la liste est alors vide et sans valeur). */
  disponible: boolean;
  /** Premier jour dont les passages en inactif sont recensés (ISO, jour) : rien avant. */
  depuis: string | null;
  lignes: ClientPasseInactif[];
};

/** Rôles qui voient le bouton : l'encadrement et l'ADV (qui reçoit les envois). */
const ROLES_INACTIFS: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'ADV'];
export const peutVoirPassesInactifs = (role: Role): boolean => ROLES_INACTIFS.includes(role);

/** Mois demandé, « AAAA-MM » (valeur d'un champ `type="month"`). */
export const moisValide = (mois: unknown): mois is string =>
  typeof mois === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(mois);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_LIGNES = 2000;

const texte = (v: unknown, max = 160): string | null =>
  typeof v === 'string' && v.trim() ? v.trim().slice(0, max) : null;

const dateIso = (v: unknown): string | null => {
  const t = typeof v === 'string' ? v : '';
  return t && Number.isFinite(Date.parse(t)) ? t : null;
};

/**
 * Lecture défensive de `GET /clients/passes-inactifs` : id en UUID, date valide, champs bornés, au plus 2 000 lignes.
 * Une ligne mal formée est écartée ; toute autre forme de réponse donne « aucune ligne ».
 */
export function assainirPassesInactifs(brut: unknown): PassesInactifs {
  const o = (brut && typeof brut === 'object' ? brut : {}) as { disponible?: unknown; depuis?: unknown; lignes?: unknown };
  const lignes: ClientPasseInactif[] = [];
  for (const it of Array.isArray(o.lignes) ? o.lignes.slice(0, MAX_LIGNES) : []) {
    const l = (it && typeof it === 'object' ? it : {}) as Record<string, unknown>;
    const id = texte(l.id, 64);
    const enseigne = texte(l.enseigne);
    const date = dateIso(l.date);
    if (!id || !UUID.test(id) || !enseigne || !date) continue;
    lignes.push({
      id,
      enseigne,
      codeAs400: texte(l.codeAs400, 40) ?? '',
      ville: texte(l.ville),
      date,
      modifiePar: texte(l.modifiePar),
      dr: texte(l.dr),
      retireAs400: l.retireAs400 === true,
      envoyeAdvLe: dateIso(l.envoyeAdvLe),
    });
  }
  return { disponible: o.disponible !== false, depuis: dateIso(o.depuis), lignes };
}

const FORMAT_DATE = new Intl.DateTimeFormat('fr-FR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'Europe/Paris',
});

/** « 09/11/2026 09:22 » (heure de Paris). */
export function dateHeure(iso: string): string {
  return FORMAT_DATE.format(new Date(iso)).replace(',', '').replace(/ /g, ' ');
}

/** « 1er octobre 2026 ». */
export function jourLong(iso: string): string {
  const d = new Date(iso);
  const jour = d.toLocaleDateString('fr-FR', { day: 'numeric', timeZone: 'Europe/Paris' });
  const reste = d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric', timeZone: 'Europe/Paris' });
  return `${jour === '1' ? '1er' : jour} ${reste}`;
}

/** Colonne « Envoyé à l'ADV » : la date d'envoi, ou la raison pour laquelle rien n'est parti. */
export function envoiAdv(l: ClientPasseInactif): { envoye: boolean; texte: string } {
  if (l.envoyeAdvLe) return { envoye: true, texte: dateHeure(l.envoyeAdvLe) };
  return { envoye: false, texte: l.retireAs400 ? "Non envoyé : client retiré de l'AS400" : 'Non envoyé' };
}

/** Mois courant « AAAA-MM » à Paris. */
export function moisCourant(maintenant: Date = new Date()): string {
  const p = new Intl.DateTimeFormat('fr-FR', { year: 'numeric', month: '2-digit', timeZone: 'Europe/Paris' }).formatToParts(maintenant);
  return `${p.find((x) => x.type === 'year')?.value}-${p.find((x) => x.type === 'month')?.value}`;
}

/** Cellule CSV : guillemets doublés, et neutralisation des formules (=, +, -, @) que le tableur exécuterait. */
function cellule(v: string): string {
  const sure = /^[=+\-@\t\r]/.test(v) ? `'${v}` : v;
  return `"${sure.replace(/"/g, '""')}"`;
}

/** CSV pour Excel français : séparateur « ; », fins de ligne CRLF, BOM UTF-8 en tête. */
export function versCsv(lignes: ClientPasseInactif[]): string {
  const entete = ['Enseigne', 'Code', 'Ville', 'Date', 'Modifié par', 'DR', "Envoyé à l'ADV"];
  const corps = lignes.map((l) =>
    [l.enseigne, l.codeAs400, l.ville ?? '', dateHeure(l.date), l.modifiePar ?? '', l.dr ?? '', envoiAdv(l).texte].map(cellule).join(';'),
  );
  return `﻿${[entete.map(cellule).join(';'), ...corps].join('\r\n')}\r\n`;
}

export const nomFichierCsv = (mois: string) => `clients-passes-inactifs-${mois}.csv`;
