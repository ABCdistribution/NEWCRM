export function ActiveBadge({ active }: { active: boolean }) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${
        active
          ? 'bg-green-600/10 text-green-700 dark:text-green-400'
          : 'bg-neutral-400/15 text-neutral-500'
      }`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${active ? 'bg-green-500' : 'bg-neutral-400'}`} />
      {active ? 'Actif' : 'Inactif'}
    </span>
  );
}

export const ROLE_LABELS: Record<string, string> = {
  COMMERCIAL: 'Commercial',
  CHEF_SECTEUR: 'Chef de secteur',
  ADMIN: 'Administrateur',
  DIRECTEUR_REGIONAL: 'Directeur régional',
  DIRECTION: 'Direction',
  ADV: 'ADV',
  MARKETING: 'Marketing',
};

export function RoleBadge({ role }: { role: string }) {
  const admin = role === 'ADMIN';
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
        admin ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400' : 'bg-brand/10 dark:bg-accent/10 text-brand'
      }`}
    >
      {ROLE_LABELS[role] ?? role}
    </span>
  );
}
