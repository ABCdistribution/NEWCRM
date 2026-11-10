import type { ProspectStatut, ProspectSource } from '@/lib/api';

export const STATUT_LABELS: Record<ProspectStatut, string> = {
  NOUVEAU: 'Fiche créée',
  CONTACTE: 'Prise de contact',
  PROPOSITION: 'Proposition',
  VISITE: 'Visite',
  NEGOCIATION: 'Négociation',
  GAGNE: 'Gagné',
  PERDU: 'Perdu',
};

// Contenu clair : texte en -800 sur teinte /15 (au moins 5,5:1), comme class-badge.tsx. Les -400 / -500 sont sous 4,5:1.
const STATUT_STYLES: Record<ProspectStatut, string> = {
  NOUVEAU: 'bg-neutral-400/15 text-neutral-700',
  CONTACTE: 'bg-sky-500/15 text-sky-800',
  PROPOSITION: 'bg-amber-500/15 text-amber-800',
  VISITE: 'bg-indigo-500/15 text-indigo-800',
  NEGOCIATION: 'bg-orange-500/15 text-orange-800',
  GAGNE: 'bg-emerald-500/15 text-emerald-800',
  PERDU: 'bg-red-500/15 text-red-800',
};

/** Couleur d'accent (barre / point) par étape — utile pour les colonnes du pipeline. */
export const STATUT_ACCENT: Record<ProspectStatut, string> = {
  NOUVEAU: 'bg-neutral-400',
  CONTACTE: 'bg-sky-500',
  PROPOSITION: 'bg-amber-500',
  VISITE: 'bg-indigo-500',
  NEGOCIATION: 'bg-orange-500',
  GAGNE: 'bg-emerald-500',
  PERDU: 'bg-red-400',
};

export const SOURCE_LABELS: Record<ProspectSource, string> = {
  SALON: 'Salon',
  RECOMMANDATION: 'Recommandation',
  TERRAIN: 'Terrain',
  WEB: 'Web',
};

export function StatutBadge({ value }: { value: ProspectStatut }) {
  return (
    <span
      className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
        STATUT_STYLES[value] ?? 'bg-neutral-400/15 text-neutral-700'
      }`}
    >
      {STATUT_LABELS[value] ?? value}
    </span>
  );
}
