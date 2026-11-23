/**
 * Jours fériés français (métropole), fonctions pures sur des « jours » = minuits UTC (voir `pem.dates.ts`).
 * Fixes : 1er janvier, 1er mai, 8 mai, 14 juillet, 15 août, 1er novembre, 11 novembre, 25 décembre.
 * Mobiles (dépendent de Pâques) : lundi de Pâques (+1), Ascension (+39), lundi de Pentecôte (+50).
 */
const JOUR_MS = 86_400_000;

/** Dimanche de Pâques (calendrier grégorien, algorithme de Meeus/Jones/Butcher), en minuit UTC. */
export function paques(annee: number): Date {
  const a = annee % 19;
  const b = Math.floor(annee / 100);
  const c = annee % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const mois = Math.floor((h + l - 7 * m + 114) / 31); // 3 = mars, 4 = avril
  const jour = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(annee, mois - 1, jour));
}

const cache = new Map<number, ReadonlySet<string>>();

function cle(jour: Date): string {
  return jour.toISOString().slice(0, 10);
}

/** Jours fériés d'une année, sous forme de textes yyyy-mm-dd. */
export function joursFeriesDeLAnnee(annee: number): ReadonlySet<string> {
  const connu = cache.get(annee);
  if (connu) return connu;
  const p = paques(annee).getTime();
  const fixes = [
    [1, 1],
    [5, 1],
    [5, 8],
    [7, 14],
    [8, 15],
    [11, 1],
    [11, 11],
    [12, 25],
  ].map(([mois, jour]) => cle(new Date(Date.UTC(annee, mois - 1, jour))));
  const mobiles = [1, 39, 50].map((n) => cle(new Date(p + n * JOUR_MS)));
  const ensemble: ReadonlySet<string> = new Set([...fixes, ...mobiles]);
  cache.set(annee, ensemble);
  return ensemble;
}

/** Le jour (minuit UTC) est-il un jour férié français ? */
export function estJourFerie(jour: Date): boolean {
  return joursFeriesDeLAnnee(jour.getUTCFullYear()).has(cle(jour));
}
