/** Types et logique pure du suivi PEM : indicateur de la fiche client et fréquence des visites par classe (A à G). */
import type { Role } from './roles';

/** Activer / désactiver le suivi PEM d'un magasin : mêmes rôles que `PATCH /clients/:id/suivi-pem` (le DR est limité à sa région par l'API). */
export const ROLES_SUIVI_PEM: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'];

/** Lire les propositions ouvertes d'un magasin : mêmes rôles que `GET /pem/propositions`. */
export const ROLES_LECTURE_PROPOSITIONS_PEM: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'COMMERCIAL'];

/** Modifier la fréquence par classe : mêmes rôles que `PUT /pem/frequences`. */
export const ROLES_FREQUENCES_PEM: readonly Role[] = ['ADMIN', 'DIRECTION'];

/** Champ `suiviPem` que l'API ajoute aux clients (liste, détail, mode enrichi). */
export type AvecSuiviPem = { suiviPem?: boolean };

export const CLASSES_PEM = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;
export type ClassePem = (typeof CLASSES_PEM)[number];

export const SEMAINES_MIN = 1;
export const SEMAINES_MAX = 52;

export type FrequencesPem = {
  classes: { niveauClass: ClassePem; semaines: number }[];
  /** Fréquence d'un magasin sans classe (non modifiable). */
  sansClasse: number;
};

export type PropositionPem = {
  id: string;
  dateProposee: string;
  statut: string;
  nbReports: number;
  obligatoire: boolean;
  reportsRestants: number;
  promoteur: { id?: string; displayName: string } | null;
};

/** Résultat de l'activation / désactivation du suivi PEM (Server Action). */
export type ReponseSuiviPem =
  | { error: string }
  | { error: null; suiviPem: boolean; proposition: PropositionPem | null };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function estUuid(valeur: string): boolean {
  return UUID.test(valeur);
}

export function estClassePem(valeur: unknown): valeur is ClassePem {
  return typeof valeur === 'string' && (CLASSES_PEM as readonly string[]).includes(valeur);
}

/** Nombre entier de semaines de 1 à 52 (texte ou nombre), ou null. */
export function semainesValides(valeur: unknown): number | null {
  const n = typeof valeur === 'string' && /^\s*\d{1,3}\s*$/.test(valeur) ? Number(valeur) : valeur;
  if (typeof n !== 'number' || !Number.isInteger(n) || n < SEMAINES_MIN || n > SEMAINES_MAX) return null;
  return n;
}

export const libelleSemaines = (n: number): string => `${n} semaine${n > 1 ? 's' : ''}`;

/**
 * Fréquences saisies (champs `semaines-A` … `semaines-G`) : une valeur par classe, toutes obligatoires. Renvoie la liste
 * prête pour l'API ou un message précisant la classe en cause.
 */
export function lireFrequences(
  lire: (nom: string) => string,
): { classes: { niveauClass: ClassePem; semaines: number }[]; erreur: null } | { classes: null; erreur: string } {
  const classes: { niveauClass: ClassePem; semaines: number }[] = [];
  for (const niveauClass of CLASSES_PEM) {
    const semaines = semainesValides(lire(`semaines-${niveauClass}`));
    if (semaines === null) {
      return {
        classes: null,
        erreur: `Classe ${niveauClass} : indiquez un nombre entier de semaines entre ${SEMAINES_MIN} et ${SEMAINES_MAX}.`,
      };
    }
    classes.push({ niveauClass, semaines });
  }
  return { classes, erreur: null };
}

/** Réponse de `GET /pem/frequences` contrôlée (7 classes A→G dans l'ordre), ou null si elle est inattendue. */
export function lireReponseFrequences(corps: unknown): FrequencesPem | null {
  if (typeof corps !== 'object' || corps === null) return null;
  const { classes, sansClasse } = corps as { classes?: unknown; sansClasse?: unknown };
  if (!Array.isArray(classes) || typeof sansClasse !== 'number') return null;
  const parClasse = new Map<string, number>();
  for (const ligne of classes) {
    const o = ligne && typeof ligne === 'object' ? (ligne as Record<string, unknown>) : null;
    if (!o || !estClassePem(o.niveauClass)) return null;
    const semaines = semainesValides(o.semaines);
    if (semaines === null) return null;
    parClasse.set(o.niveauClass, semaines);
  }
  const ordonnees = CLASSES_PEM.map((niveauClass) => ({ niveauClass, semaines: parClasse.get(niveauClass) }));
  if (ordonnees.some((c) => c.semaines === undefined)) return null;
  return { classes: ordonnees as FrequencesPem['classes'], sansClasse };
}

/** Fréquence applicable à un magasin selon sa classe (« sans classe » si elle est absente ou inconnue). */
export function frequenceDuMagasin(frequences: FrequencesPem, niveauClass: string | null): number {
  return frequences.classes.find((c) => c.niveauClass === niveauClass)?.semaines ?? frequences.sansClasse;
}

/** Proposition de la réponse de l'API contrôlée (null si absente ou mal formée). */
export function lireProposition(valeur: unknown): PropositionPem | null {
  if (typeof valeur !== 'object' || valeur === null) return null;
  const p = valeur as Record<string, unknown>;
  if (typeof p.id !== 'string' || typeof p.dateProposee !== 'string' || !/^\d{4}-\d{2}-\d{2}/.test(p.dateProposee)) return null;
  const promoteur =
    p.promoteur && typeof p.promoteur === 'object' && typeof (p.promoteur as { displayName?: unknown }).displayName === 'string'
      ? { displayName: (p.promoteur as { displayName: string }).displayName }
      : null;
  return {
    id: p.id,
    dateProposee: p.dateProposee.slice(0, 10),
    statut: typeof p.statut === 'string' ? p.statut : 'PROPOSEE',
    nbReports: typeof p.nbReports === 'number' ? p.nbReports : 0,
    obligatoire: p.obligatoire === true,
    reportsRestants: typeof p.reportsRestants === 'number' ? p.reportsRestants : 0,
    promoteur,
  };
}

/** Première proposition ouverte (la plus proche) d'une réponse de `GET /pem/propositions` ; null si aucune ou réponse inattendue. */
export function lirePropositionOuverte(corps: unknown): PropositionPem | null {
  if (typeof corps !== 'object' || corps === null) return null;
  const { data } = corps as { data?: unknown };
  if (!Array.isArray(data)) return null;
  for (const ligne of data) {
    const p = lireProposition(ligne);
    if (p && (p.statut === 'PROPOSEE' || p.statut === 'ACCEPTEE')) return p;
  }
  return null;
}

const JOUR_FR = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });

/** « mercredi 2 décembre 2026 » pour un jour `yyyy-mm-dd` (sans décalage de fuseau) ; le texte brut si illisible. */
export function formaterJourPem(jour: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(jour);
  if (!m) return jour;
  const date = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  return Number.isNaN(date.getTime()) ? jour : JOUR_FR.format(date);
}
