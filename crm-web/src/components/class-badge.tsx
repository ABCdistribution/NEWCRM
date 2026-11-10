/**
 * Pastille de classe client A→G, colorée selon le niveau.
 * Le contenu de crm-web est clair (`.dark` n'est posé que sur le menu) : texte en `-800` sur teinte `/15`
 * pour un contraste d'au moins 5,5:1 (AA : 4,5:1) sur blanc, fond de page bleu ou lilas.
 */
const COLORS: Record<string, string> = {
  A: 'bg-emerald-500/15 text-emerald-800',
  B: 'bg-green-500/15 text-green-800',
  C: 'bg-lime-500/15 text-lime-800',
  D: 'bg-yellow-500/15 text-yellow-800',
  E: 'bg-amber-500/15 text-amber-800',
  F: 'bg-orange-500/15 text-orange-800',
  G: 'bg-red-500/15 text-red-800',
};

const DIMENSIONS = {
  xs: 'h-4 w-4 text-[9px]',
  sm: 'h-5 w-5 text-[10px]',
  md: 'h-6 w-6 text-xs',
} as const;

export function ClassBadge({ value, size = 'sm' }: { value: string | null; size?: keyof typeof DIMENSIONS }) {
  if (!value) return null;
  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-full font-bold ${DIMENSIONS[size]} ${
        COLORS[value] ?? 'bg-neutral-500/15 text-neutral-700'
      }`}
      title={`Classe ${value}`}
    >
      {value}
    </span>
  );
}
