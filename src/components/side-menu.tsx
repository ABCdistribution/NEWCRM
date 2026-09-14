'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home,
  Newspaper,
  Route,
  Target,
  FileText,
  Users,
  UsersRound,
  AlertTriangle,
  Sprout,
  Database,
  Settings,
  LogOut,
  ArrowLeftRight,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { ThemeToggle } from './theme-toggle';
import { UniverseSwitchOverlay } from './universe-switch-overlay';
import type { Me } from '@/lib/api';

type Leaf = { href: string; label: string; icon: LucideIcon; roles?: string[] };
type Section = { label: string | null; children: Leaf[] };

/**
 * Navigation helios — le portail de PILOTAGE (direction / encadrement).
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
      { href: '/pilotage/prospects', label: 'Prospection', icon: Sprout, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/tournees', label: 'Planification tournées', icon: Route },
      { href: '/pilotage/alertes', label: 'Alertes', icon: AlertTriangle, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/mon-equipe', label: 'Mon équipe', icon: UsersRound, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'] },
      { href: '/pilotage/rapports', label: 'Rapports d’activité', icon: FileText, roles: ['ADMIN', 'DIRECTION'] },
      { href: '/pilotage/objectifs', label: 'Objectifs', icon: Target, roles: ['ADMIN', 'DIRECTION'] },
    ],
  },
  {
    label: 'Administration',
    children: [
      { href: '/pilotage/users', label: 'Utilisateurs', icon: Users, roles: ['ADMIN'] },
      { href: '/pilotage/imports', label: 'Imports Minos', icon: Database, roles: ['ADMIN'] },
      { href: '/pilotage/parametres', label: 'Paramètres', icon: Settings, roles: ['ADMIN'] },
    ],
  },
];

function isActive(pathname: string, href: string) {
  return href === '/pilotage' ? pathname === '/pilotage' : pathname === href || pathname.startsWith(`${href}/`);
}

const SWITCH_ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

export function SideMenu({ me, kratosPort }: { me: Me; kratosPort: string }) {
  const pathname = usePathname();
  const canSwitch = SWITCH_ROLES.includes(me.role);
  const [switching, setSwitching] = useState(false);
  // Kratos tourne sur le même serveur : on reprend l'hôte utilisé pour accéder à Helios.
  // L'animation de bascule joue d'abord, puis la navigation part (le voile reste jusqu'au déchargement).
  const goKratos = () => {
    if (switching) return;
    setSwitching(true);
    window.setTimeout(() => {
      window.location.href = `${window.location.protocol}//${window.location.hostname}:${kratosPort}`;
    }, 1100);
  };

  return (
    <aside className="sticky top-0 z-20 flex h-screen w-60 shrink-0 flex-col border-r border-neutral-200 bg-white text-neutral-800 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-100">
      {switching ? (
        <UniverseSwitchOverlay
          fromSrc="/helios-transparent.png"
          toSrc="/kratos-transparent.png"
          toName="Kratos"
        />
      ) : null}
      {/* Marque */}
      <Link href="/pilotage" className="flex items-center justify-center px-4 py-5">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/helios-transparent.png" alt="Helios" className="h-16 w-auto" />
      </Link>

      {/* Bascule vers l'univers terrain (Kratos) — encadrement uniquement */}
      {canSwitch ? (
        <button
          type="button"
          onClick={goKratos}
          className="mx-3 mb-3 flex items-center gap-2.5 rounded-xl border border-neutral-200 p-2.5 text-left transition hover:border-brand hover:bg-neutral-50 dark:border-navy-700 dark:hover:border-accent dark:hover:bg-navy-800"
          title="Basculer sur l'espace terrain (Kratos)"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/kratos-transparent.png" alt="" className="h-9 w-9 shrink-0 object-contain" />
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold">Espace terrain</p>
            <p className="text-[11px] text-neutral-400">Basculer sur Kratos</p>
          </div>
          <ArrowLeftRight size={15} className="shrink-0 text-neutral-400" />
        </button>
      ) : null}

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
