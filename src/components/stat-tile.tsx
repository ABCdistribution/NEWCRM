import type { LucideIcon } from 'lucide-react';

/** Tuile KPI façon Advisian, aux couleurs Helios : icône sur pastille violette pâle. */
export function StatTile({
  icon: Icon,
  label,
  value,
  hint,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="flex items-start gap-3.5 rounded-2xl bg-white p-5 shadow-card">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand/10">
        <Icon size={20} className="text-brand" />
      </span>
      <div className="min-w-0">
        <p className="text-sm text-neutral-500">{label}</p>
        <p className="mt-0.5 truncate text-2xl font-bold tracking-tight">{value}</p>
        {hint ? <p className="mt-0.5 truncate text-xs text-neutral-400">{hint}</p> : null}
      </div>
    </div>
  );
}
