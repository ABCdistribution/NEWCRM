'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home,
  ClipboardList,
  Store,
  Package,
  Route,
  Target,
  ShoppingCart,
  ShieldAlert,
  BadgePercent,
  Users,
  Database,
  Settings,
  LogOut,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { ThemeToggle } from './theme-toggle';
import type { Me } from '@/lib/api';

type Leaf = { href: string; label: string; icon: LucideIcon; roles?: string[] };
type Section = { label: string | null; children: Leaf[] };

/**
 * Navigation helios — le portail de PILOTAGE (direction / encadrement).
 * Vue globale : toute la force de vente, tous les magasins, toutes les commandes.
 */
const SECTIONS: Section[] = [
  { label: null, children: [{ href: '/', label: 'Accueil', icon: Home }] },
  {
    label: 'Pilotage',
    children: [
      { href: '/objectifs', label: 'Objectifs', icon: Target, roles: ['ADMIN', 'DIRECTION'] },
      { href: '/tournees', label: 'Planification tournées', icon: Route },
      { href: '/questionnaire', label: 'Questionnaire visite', icon: ClipboardList, roles: ['ADMIN', 'DIRECTION'] },
    ],
  },
  {
    label: 'Référentiel',
    children: [
      { href: '/clients', label: 'Magasins', icon: Store },
      { href: '/commandes', label: 'Commandes', icon: ShoppingCart },
      { href: '/produits', label: 'Produits', icon: Package },
      { href: '/promos', label: 'Promos / PEM', icon: BadgePercent },
      { href: '/qualite', label: 'Qualité & rappels', icon: ShieldAlert },
    ],
  },
  {
    label: 'Administration',
    children: [
      { href: '/users', label: 'Utilisateurs', icon: Users, roles: ['ADMIN'] },
      { href: '/imports', label: 'Imports Minos', icon: Database, roles: ['ADMIN'] },
      { href: '/parametres', label: 'Paramètres', icon: Settings, roles: ['ADMIN'] },
    ],
  },
];

function isActive(pathname: string, href: string) {
  return href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(`${href}/`);
}

export function SideMenu({ me }: { me: Me }) {
  const pathname = usePathname();

  return (
    // `dark` : la sidebar rend sa version sombre (violet) alors que le reste du site est clair.
    <aside className="sticky top-0 z-20 flex h-screen w-60 shrink-0 flex-col border-r border-neutral-200 bg-white text-neutral-800 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-100">
      {/* Marque */}
      <Link href="/" className="flex items-center gap-2.5 px-4 py-4">
        <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand text-sm font-bold text-white dark:bg-accent dark:text-brand">
          H
        </span>
        <span className="text-lg font-bold tracking-tight">Helios</span>
      </Link>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 pb-4">
        {SECTIONS.map((section, i) => {
          const children = section.children.filter((c) => !c.roles || c.roles.includes(me.role));
          if (children.length === 0) return null;
          return (
            <div key={section.label ?? i} className={i > 0 ? 'mt-5' : ''}>
              {section.label ? (
                <p className="px-3 pb-1.5 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
                  {section.label}
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
                        className={`group flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition ${
                          active
                            ? 'bg-brand font-medium text-white shadow-sm dark:bg-accent dark:text-brand'
                            : 'text-neutral-600 hover:bg-neutral-100 hover:text-neutral-900 dark:text-white dark:hover:bg-accent/20'
                        }`}
                      >
                        {/* Surbrillance or translucide au survol ; texte blanc et icônes mauves conservés. */}
                        <Icon size={17} className={`shrink-0 ${active ? '' : 'text-[#A78BDA]'}`} />
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
            <p className="truncate text-sm font-medium">{me.displayName}</p>
            <p className="truncate text-xs text-neutral-400">{me.email ?? me.username}</p>
          </div>
          <ThemeToggle />
          <form action={logout}>
            <button
              type="submit"
              className="rounded-lg p-2 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/40"
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

function initials(displayName: string): string {
  return displayName
    .split(/\s+/)
    .map((s) => s[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase();
}
