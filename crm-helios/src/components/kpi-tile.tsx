import { Info } from 'lucide-react';

export type KpiPill = { text: string; tone: 'up' | 'down' | 'warn' | 'neutral' };

const PILL_STYLES: Record<KpiPill['tone'], string> = {
  up: 'bg-emerald-500/12 text-emerald-600 dark:text-emerald-400',
  down: 'bg-red-500/12 text-red-500 dark:text-red-400',
  warn: 'bg-amber-500/15 text-amber-600 dark:text-amber-400',
  neutral: 'bg-neutral-400/15 text-neutral-500',
};

/**
 * Tuile KPI façon SaaS/CRM : label + icône info, grand chiffre, sous-ligne
 * avec pastille d'état colorée. Aux couleurs Helios (violet/or via shadow-card).
 */
export function KpiTile({
  label,
  info,
  value,
  sub,
  pill,
}: {
  label: string;
  info?: string;
  value: string;
  sub?: string;
  pill?: KpiPill;
}) {
  return (
    <div className="rounded-2xl bg-white p-5 shadow-card">
      <div className="flex items-center gap-1.5 text-sm text-neutral-500">
        <span>{label}</span>
        {info ? (
          <span title={info} className="inline-flex cursor-help text-neutral-300 dark:text-neutral-600">
            <Info size={13} />
          </span>
        ) : null}
      </div>
      <p className="mt-2 text-3xl font-bold tracking-tight tabular-nums text-neutral-900 dark:text-neutral-50">
        {value}
      </p>
      {sub || pill ? (
        <div className="mt-1.5 flex items-center gap-2 text-xs text-neutral-400">
          {sub ? <span>{sub}</span> : null}
          {pill ? (
            <span className={`inline-flex items-center rounded-full px-1.5 py-0.5 text-[11px] font-semibold ${PILL_STYLES[pill.tone]}`}>
              {pill.text}
            </span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
