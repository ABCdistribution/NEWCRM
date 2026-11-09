// Motifs de perte d'un prospect (valeurs de l'énumération MotifPerteProspect de l'API).
// Module pur : partagé par le stepper de la fiche, le Kanban et la Server Action qui valide la valeur reçue.

export const MOTIFS_PERTE = [
  ['PRIX', 'Prix'],
  ['CONCURRENCE', 'Concurrent en place'],
  ['PAS_DE_BESOIN', 'Pas de besoin'],
  ['SANS_REPONSE', 'Sans réponse'],
  ['AUTRE', 'Autre'],
] as const;

export type MotifPerteCode = (typeof MOTIFS_PERTE)[number][0];

export function estMotifPerte(v: unknown): v is MotifPerteCode {
  return typeof v === 'string' && MOTIFS_PERTE.some(([code]) => code === v);
}
