import type { LucideIcon } from 'lucide-react';

/**
 * Jauge d'objectif. Si `pct` est null (objectif non défini), on montre le réalisé
 * et une note, sans barre trompeuse.
 */
export function GaugeCard({
  icon: Icon,
  label,
  realiseLabel,
  cibleLabel,
  pct,
  placeholder,
}: {
  icon: LucideIcon;
  label: string;
  realiseLabel: string;
  cibleLabel?: string;
  pct: number | null;
  placeholder?: string;
}) {
  const clamped = pct !== null ? Math.max(0, Math.min(100, pct)) : null;

  return (
    <div className="rounded-2xl bg-white shadow-card p-5">
      <div className="flex items-center gap-2 text-sm font-medium text-neutral-500">
        <Icon size={16} />
        {label}
      </div>

      <div className="mt-3 flex flex-wrap items-baseline gap-x-2">
        <span className="text-3xl font-bold tracking-tight text-brand dark:text-accent">{realiseLabel}</span>
        {cibleLabel ? <span className="text-neutral-400">/ {cibleLabel}</span> : null}
        {clamped !== null ? (
          <span className="ml-auto text-sm font-medium text-brand dark:text-accent">{Math.round(clamped)}%</span>
        ) : null}
      </div>

      {clamped !== null ? (
        <div className="mt-3 h-2.5 w-full overflow-hidden rounded-full bg-neutral-100 dark:bg-navy-800">
          <div className="h-full rounded-full bg-brand dark:bg-accent" style={{ width: `${clamped}%` }} />
        </div>
      ) : placeholder ? (
        <p className="mt-3 rounded-lg border border-dashed border-neutral-300 px-3 py-2 text-xs text-neutral-400">
          {placeholder}
        </p>
      ) : null}
    </div>
  );
}
