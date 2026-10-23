import Link from 'next/link';

export const ONGLETS = [
  { id: 'apercu', label: "Vue d'ensemble" },
  { id: 'utilisateurs', label: 'Utilisateurs' },
  { id: 'organisation', label: 'Organisation' },
  { id: 'synchros', label: 'Synchronisations' },
  { id: 'mobile', label: 'Mobile', bientot: true },
  { id: 'contenus', label: 'Contenus' },
  { id: 'configuration', label: 'Configuration', bientot: true },
  { id: 'journal', label: "Journal d'audit", bientot: true },
] as const;

export type OngletId = (typeof ONGLETS)[number]['id'];

export function ongletValide(valeur: string | undefined): OngletId {
  return ONGLETS.find((o) => o.id === valeur)?.id ?? 'apercu';
}

/** Barre d'onglets de l'administration : l'onglet actif est porté par `?onglet=` (lien partageable). */
export function AdminOnglets({ actif }: { actif: OngletId }) {
  return (
    <nav aria-label="Sections de l'administration" className="-mx-1 flex gap-1 overflow-x-auto border-b border-neutral-200 px-1">
      {ONGLETS.map((o) => {
        const courant = o.id === actif;
        return (
          <Link
            key={o.id}
            href={`/pilotage/admin?onglet=${o.id}`}
            aria-current={courant ? 'page' : undefined}
            className={`-mb-px inline-flex shrink-0 items-center gap-1.5 border-b-2 px-3 py-2.5 text-sm font-medium transition ${
              courant
                ? 'border-violet-600 text-violet-700'
                : 'border-transparent text-neutral-500 hover:border-neutral-300 hover:text-neutral-800'
            }`}
          >
            {o.label}
            {'bientot' in o ? (
              <span className="rounded-full bg-neutral-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-neutral-500">
                bientôt
              </span>
            ) : null}
          </Link>
        );
      })}
    </nav>
  );
}
