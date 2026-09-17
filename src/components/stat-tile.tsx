import type { LucideIcon } from 'lucide-react';

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
    <div className="relative overflow-hidden rounded-2xl bg-white shadow-card p-5">
      <span className="absolute inset-x-0 top-0 h-0.5 bg-gradient-to-r from-violet-400 to-violet-500" />
      <div className="flex items-center justify-between">
        <span className="text-sm text-neutral-500">{label}</span>
        <Icon size={18} className="text-[#7D8CCE]" />
      </div>
      <p className="mt-2 text-2xl font-bold tracking-tight text-brand dark:text-accent">{value}</p>
      {hint ? <p className="mt-1 text-xs text-neutral-400">{hint}</p> : null}
    </div>
  );
}
