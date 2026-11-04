'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Montserrat } from 'next/font/google';
import {
  Home,
  Store,
  Route,
  Newspaper,
  FileText,
  Users,
  UsersRound,
  AlertTriangle,
  Sprout,
  Database,
  Settings,
  LogOut,
  ClipboardCheck,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import type { Me } from '@/lib/api';

/** Police du mot-symbole « ABC » en tête de menu (aspect logo). */
const policeLogo = Montserrat({ subsets: ['latin'], weight: '800' });

type Leaf = { href: string; label: string; icon: LucideIcon; roles?: string[] };
type Section = { label: string | null; children: Leaf[] };

/**
 * Navigation ABC Pilot — le portail de PILOTAGE (direction / encadrement).
 * Vue globale : toute la force de vente, tous les magasins, toutes les commandes.
 */
const SECTIONS: Section[] = [
  {
    label: null,
    children: [
      { href: '/pilotage', label: 'Accueil', icon: Home },
      { href: '/pilotage/news', label: 'Les News', icon: Newspaper },
    ],
  },
  {
    label: 'Pilotage',
    children: [
      // Planning PERSONNEL de l'encadrement : prospection + suivi magasins (≠ visites promoteurs ABC Sales).
      { href: '/pilotage/ma-tournee', label: "Mon planning d'activité", icon: Route, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/prospects', label: 'Prospection', icon: Sprout, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // Suivi des magasins déjà gérés : classification, KPI, visites, promoteur en charge.
      { href: '/pilotage/magasins', label: 'Clients', icon: Store, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // La planification des tournées vit désormais côté ABC Sales (/planification).
      { href: '/pilotage/alertes', label: 'Alertes', icon: AlertTriangle, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/mon-equipe', label: 'Mon équipe', icon: UsersRound, roles: ['ADMIN', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // Rapports d'activité hebdomadaires des CS / DR : tournée prévue, tournée réalisée, rapport validé (lecture seule).
      { href: '/pilotage/rapports', label: "Rapports d'activité", icon: ClipboardCheck, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'] },
      // Objectifs : alimentés par API (import), plus de page de saisie.
    ],
  },
  {
    label: 'Administration',
    children: [
      { href: '/pilotage/admin', label: 'Administration', icon: ShieldCheck, roles: ['ADMIN'] },
    ],
  },
];

/** Fond du menu Direction commerciale : violet encre uni (#2E1B56, couleur de la maquette mobile). */
const FOND_MENU: React.CSSProperties = {
  backgroundColor: '#2E1B56',
};

function isActive(pathname: string, href: string) {
  return href === '/pilotage' ? pathname === '/pilotage' : pathname === href || pathname.startsWith(`${href}/`);
}

export function SideMenu({ me }: { me: Me }) {
  const pathname = usePathname();

  return (
    <aside className="dark sticky top-0 z-20 flex h-screen w-64 shrink-0 flex-col border-r border-navy-700 bg-navy-950 text-neutral-100" style={FOND_MENU}>
      {/* Marque */}
      <Link href="/pilotage" className="flex flex-col items-center justify-center gap-1.5 px-4 py-5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">
        <span className={`${policeLogo.className} select-none text-5xl font-extrabold leading-none tracking-[0.18em] text-white`} aria-label="ABC">ABC</span>
        <span className="text-xs font-medium text-white/70">Direction commerciale</span>
      </Link>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 pb-4 [scrollbar-color:#A6A4D5_transparent]">
        {SECTIONS.map((section, i) => {
          const children = section.children.filter((c) => !c.roles || c.roles.includes(me.role));
          if (children.length === 0) return null;
          return (
            <div key={section.label ?? i} className={i > 0 ? 'mt-5' : ''}>
              {section.label ? (
                <p className="flex items-center gap-3 px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-400 dark:text-indigo-200/80">
                  <span>{section.label}</span>
                  <span aria-hidden className="h-px flex-1 bg-white/15" />
                </p>
              ) : null}
              <ul className="flex flex-col gap-0.5">
                {children.map((c) => {
                  const Icon = c.icon;
                  const active = isActive(pathname, c.href);
                  return (
                    <li key={c.href}>
                      <Link
                        href={c.href}
                        className={`group flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-[15px] transition ${
                          active
                            ? 'bg-neutral-100 font-semibold text-neutral-900 dark:bg-[#55399B] dark:text-white'
                            : 'text-neutral-500 hover:bg-neutral-50 hover:text-neutral-900 dark:text-white dark:hover:bg-white/10'
                        }`}
                      >
                        {/* Surbrillance or translucide au survol ; texte blanc et icônes mauves conservés. */}
                        <Icon size={19} className={`shrink-0 ${active ? 'text-brand dark:text-white' : 'text-neutral-400 dark:text-white'}`} />
                        {c.label}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}
      </nav>

      {/* Utilisateur + déconnexion */}
      <div className="border-t border-neutral-200 p-3 dark:border-navy-700">
        <div className="flex items-center gap-2.5 px-1">
          <Avatar src={`/avatar/${me.id}`} initials={initials(me.displayName)} size={36} />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium">{me.displayName}</p>
            <p className="text-xs text-neutral-400 dark:text-white">{me.poste ?? ROLE_LABELS[me.role] ?? ""}</p>
          </div>
        </div>
        <div className="mt-2 flex items-center justify-end gap-1 px-1">
          <form action={logout}>
            <button
              type="submit"
              className="rounded-lg p-2 text-neutral-400 dark:text-white transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/40"
              aria-label="Déconnexion"
              title="Déconnexion"
            >
              <LogOut size={16} />
            </button>
          </form>
        </div>
      </div>
    </aside>
  );
}

const ROLE_LABELS: Record<string, string> = {
  ADMIN: 'Administrateur',
  DIRECTION: 'Direction',
  DIRECTEUR_REGIONAL: 'Directeur régional',
  CHEF_SECTEUR: 'Chef de secteur',
  COMMERCIAL: 'Promoteur des ventes',
  ADV: 'ADV',
  MARKETING: 'Marketing',
};

function initials(displayName: string): string {
  return displayName
    .split(/\s+/)
    .map((s) => s[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase();
}
