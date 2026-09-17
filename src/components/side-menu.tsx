'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
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
  ArrowLeftRight,
  ExternalLink,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
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
      // Planning PERSONNEL de l'encadrement : prospection + suivi magasins (≠ visites promoteurs Selios).
      { href: '/pilotage/ma-tournee', label: "Mon planning d'activité", icon: Route, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/prospects', label: 'Prospection', icon: Sprout, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // Suivi des magasins déjà gérés : classification, KPI, visites, promoteur en charge.
      { href: '/pilotage/magasins', label: 'Magasins', icon: Store, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // La planification des tournées vit désormais côté Selios (/planification).
      { href: '/pilotage/alertes', label: 'Alertes', icon: AlertTriangle, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/mon-equipe', label: 'Mon équipe', icon: UsersRound, roles: ['ADMIN', 'DIRECTEUR_REGIONAL'] },
      // Rapports d'activité : consultés depuis la fiche d'un chef de secteur (Mon équipe).
      // Objectifs : alimentés par API (import), plus de page de saisie.
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

export function SideMenu({ me, seliosPort }: { me: Me; seliosPort: string }) {
  const pathname = usePathname();
  const canSwitch = SWITCH_ROLES.includes(me.role);
  const [switching, setSwitching] = useState(false);
  const [versAscendo, setVersAscendo] = useState(false);
  // Même mise en scène que la bascule d'univers, mais AscendoPilot s'ouvre dans un
  // NOUVEL onglet : le voile se retire une fois l'onglet lancé.
  const goAscendo = () => {
    if (versAscendo) return;
    setVersAscendo(true);
    window.setTimeout(() => {
      window.open('https://ascendopilot.abcosmetique.com', '_blank', 'noopener');
      setVersAscendo(false);
    }, 1100);
  };
  // Selios tourne sur le même serveur : on reprend l'hôte utilisé pour accéder à Helios.
  // L'animation de bascule joue d'abord, puis la navigation part (le voile reste jusqu'au déchargement).
  const goSelios = () => {
    if (switching) return;
    setSwitching(true);
    window.setTimeout(() => {
      window.location.href = `${window.location.protocol}//${window.location.hostname}:${seliosPort}`;
    }, 1100);
  };

  return (
    <aside className="sticky top-0 z-20 flex h-screen w-64 shrink-0 flex-col border-r border-neutral-200 bg-white text-neutral-800 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-100">
      {switching ? (
        <UniverseSwitchOverlay
          fromSrc="/helios.png"
          toSrc="/logo-selios-white.png"
          toName="Selios"
        />
      ) : null}
      {versAscendo ? (
        <UniverseSwitchOverlay
          fromSrc="/helios.png"
          toSrc="/Ascendo-pilot.png"
          toName="AscendoPilot"
        />
      ) : null}
      {/* Marque */}
      <Link href="/pilotage" className="flex items-center justify-center px-4 py-5">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo-helios-black.png" alt="Helios" className="h-32 w-auto" />
      </Link>

      {/* Bascule vers l'univers terrain (Selios) — encadrement uniquement */}
      {canSwitch ? (
        <button
          type="button"
          onClick={goSelios}
          className="mx-3 mb-3 flex items-center gap-2.5 rounded-xl border border-neutral-200 bg-white p-2.5 text-left transition hover:border-brand hover:bg-neutral-50"
          title="Basculer sur l'espace terrain (Selios)"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/Selios-logo.png" alt="" className="h-10 w-10 shrink-0 object-contain" />
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold">Espace terrain</p>
            <p className="text-[11px] text-neutral-400">Basculer sur Selios</p>
          </div>
          <ArrowLeftRight size={15} className="shrink-0 text-neutral-400" />
        </button>
      ) : null}

      {/* Outil externe AscendoPilot — animation de bascule puis nouvel onglet */}
      <button
        type="button"
        onClick={goAscendo}
        className="mx-3 mb-3 flex w-[calc(100%-1.5rem)] items-center gap-2.5 rounded-xl border border-neutral-200 bg-white p-2.5 text-left transition hover:border-brand hover:bg-neutral-50"
        title="Ouvrir AscendoPilot (nouvel onglet)"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/Ascendo-pilot.png" alt="" className="h-10 w-10 shrink-0 object-contain" />
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold">AscendoPilot</p>
          <p className="text-[11px] text-neutral-400">Outil statistique</p>
        </div>
        <ExternalLink size={15} className="shrink-0 text-neutral-400" />
      </button>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 pb-4">
        {SECTIONS.map((section, i) => {
          const children = section.children.filter((c) => !c.roles || c.roles.includes(me.role));
          if (children.length === 0) return null;
          return (
            <div key={section.label ?? i} className={i > 0 ? 'mt-5' : ''}>
              {section.label ? (
                <p className="px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-400">
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
                        className={`group flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-[15px] transition ${
                          active
                            ? 'bg-brand font-medium text-white shadow-sm dark:bg-accent dark:text-brand'
                            : 'text-neutral-600 hover:bg-neutral-100 hover:text-neutral-900 dark:text-white dark:hover:bg-accent/20'
                        }`}
                      >
                        {/* Surbrillance or translucide au survol ; texte blanc et icônes mauves conservés. */}
                        <Icon size={19} className={`shrink-0 ${active ? '' : 'text-[#A78BDA]'}`} />
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
            <p className="text-xs text-neutral-400">{me.poste ?? me.email ?? ""}</p>
          </div>
        </div>
        <div className="mt-2 flex items-center justify-end gap-1 px-1">
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
