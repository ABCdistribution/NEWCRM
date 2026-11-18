import Link from 'next/link';
import {
  LayoutDashboard,
  Users,
  Network,
  RefreshCw,
  Smartphone,
  ClipboardList,
  Library,
  SlidersHorizontal,
  ScrollText,
  type LucideIcon,
} from 'lucide-react';

export const ONGLETS: readonly { id: string; label: string; icone: LucideIcon; bientot?: boolean }[] = [
  { id: 'apercu', label: "Vue d'ensemble", icone: LayoutDashboard },
  { id: 'utilisateurs', label: 'Utilisateurs', icone: Users },
  { id: 'organisation', label: 'Organisation', icone: Network },
  { id: 'synchros', label: 'Synchronisations', icone: RefreshCw },
  { id: 'visites', label: 'Visites', icone: ClipboardList },
  { id: 'mobile', label: 'Mobile', icone: Smartphone, bientot: true },
  { id: 'contenus', label: 'Contenus', icone: Library },
  { id: 'configuration', label: 'Configuration', icone: SlidersHorizontal, bientot: true },
  { id: 'journal', label: "Journal d'audit", icone: ScrollText, bientot: true },
];

export type OngletId = 'apercu' | 'utilisateurs' | 'organisation' | 'synchros' | 'visites' | 'mobile' | 'contenus' | 'configuration' | 'journal';

export function ongletValide(valeur: string | undefined): OngletId {
  return (ONGLETS.find((o) => o.id === valeur)?.id ?? 'apercu') as OngletId;
}

/**
 * Navigation de la console d'administration : bandeau horizontal en haut, qui passe à la ligne plutôt que de défiler : toutes les rubriques restent visibles, pour laisser toute la
 * largeur au contenu. L'onglet actif est porté par `?onglet=` (lien partageable).
 */
export function AdminOnglets({ actif }: { actif: OngletId }) {
  return (
    <nav
      aria-label="Sections de l'administration"
      className="flex flex-wrap gap-1 rounded-2xl bg-white p-2 shadow-card"
    >
      {ONGLETS.map((o) => {
        const courant = o.id === actif;
        const Icone = o.icone;
        return (
          <Link
            key={o.id}
            href={`/admin?onglet=${o.id}`}
            aria-current={courant ? 'page' : undefined}
            className={`flex items-center gap-2 rounded-lg border-b-[3px] px-3 py-2 text-sm font-medium transition ${
              courant
                ? 'border-brand bg-brand/10 text-navy'
                : 'border-transparent text-neutral-600 hover:bg-neutral-50 hover:text-neutral-900'
            }`}
          >
            <Icone size={17} className={courant ? 'text-brand' : 'text-neutral-400'} aria-hidden />
            <span className="whitespace-nowrap">{o.label}</span>
            {o.bientot ? (
              <span className="ml-auto rounded-full bg-neutral-100 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-neutral-500">
                bientôt
              </span>
            ) : null}
          </Link>
        );
      })}
    </nav>
  );
}
