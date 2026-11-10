// Affichage de l'activité d'un collaborateur ou d'une région : fonctions pures (serveur ET client), testées à part.
import type { Activite } from './carte';

const FORMAT_EUROS = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/** Montant en euros entiers, à la française : « 8 450 € ». */
export const euros = (n: number) => FORMAT_EUROS.format(n);

/** Niveau d'atteinte d'un objectif : 90 % et plus, 70 à 89 %, en dessous ; « aucun » quand il n'y a pas d'objectif. */
export type NiveauObjectif = 'bon' | 'moyen' | 'bas' | 'aucun';
export function niveauObjectif(tauxPct: number | null): NiveauObjectif {
  if (tauxPct == null) return 'aucun';
  if (tauxPct >= 90) return 'bon';
  if (tauxPct >= 70) return 'moyen';
  return 'bas';
}

/** Mois de l'activité affiché : « Novembre 2026 ». */
export function libellePeriode(annee: number, mois: number): string {
  const m = new Date(annee, mois - 1, 1).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
  return m.charAt(0).toUpperCase() + m.slice(1);
}

/** Intitulé du rôle affiché : le poste de l'AD quand il est renseigné, sinon le libellé du rôle. */
export const libelleRole = (poste: string | null, defaut: string) => (poste?.trim() ? poste.trim() : defaut);

/**
 * Compteurs de l'activité du mois en quelques mots (bandeau du haut) : « 0 visite », « 2 commandes », « CA 8 450 € »,
 * « objectif 10 000 € (85 %) » ou « objectif non défini ». Zéro s'écrit au singulier.
 */
export function libelleCompteurs(a: Pick<Activite, 'visites' | 'commandes' | 'ca' | 'objectif' | 'tauxPct'>): string[] {
  const nb = (n: number, mot: string) => `${n} ${mot}${n > 1 ? 's' : ''}`;
  return [
    nb(a.visites, 'visite'),
    nb(a.commandes, 'commande'),
    `CA ${euros(a.ca)}`,
    a.objectif == null ? 'objectif non défini' : `objectif ${euros(a.objectif)}${a.tauxPct == null ? '' : ` (${a.tauxPct} %)`}`,
  ];
}

/** Phrase lisible (aussi pour les lecteurs d'écran) : « CA de 8 450 € sur 10 000 € d'objectif (84 %) ». */
export function phraseObjectif(a: Pick<Activite, 'ca' | 'objectif' | 'tauxPct'>): string {
  if (a.objectif == null || a.tauxPct == null) return `CA de ${euros(a.ca)}, objectif non défini`;
  return `CA de ${euros(a.ca)} sur ${euros(a.objectif)} d'objectif (${a.tauxPct} %)`;
}
