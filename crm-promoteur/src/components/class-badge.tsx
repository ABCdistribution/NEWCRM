/** Pastille de classe client A→G, colorée selon le niveau. */
const COLORS: Record<string, string> = {
  A: 'bg-emerald-500/15 text-emerald-400',
  B: 'bg-green-500/15 text-green-400',
  C: 'bg-lime-500/15 text-lime-400',
  D: 'bg-yellow-500/15 text-yellow-400',
  E: 'bg-amber-500/15 text-amber-400',
  F: 'bg-orange-500/15 text-orange-400',
  G: 'bg-red-500/15 text-red-400',
};

export function ClassBadge({ value, size = 'sm' }: { value: string | null; size?: 'sm' | 'xs' }) {
  if (!value) return null;
  const dims = size === 'xs' ? 'h-4 w-4 text-[9px]' : 'h-5 w-5 text-[10px]';
  return (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-full font-bold ${dims} ${
        COLORS[value] ?? 'bg-neutral-500/15 text-neutral-400'
      }`}
      title={`Classe ${value}`}
    >
      {value}
    </span>
  );
}
