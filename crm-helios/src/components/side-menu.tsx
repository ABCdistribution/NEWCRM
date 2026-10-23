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
  BarChart3,
  ClipboardCheck,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { UniverseSwitchOverlay } from './universe-switch-overlay';
import type { Me } from '@/lib/api';
import { UniverseSwitcher } from './universe-switcher';

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
      { href: '/pilotage/magasins', label: 'Magasins', icon: Store, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      // La planification des tournées vit désormais côté ABC Sales (/planification).
      { href: '/pilotage/alertes', label: 'Alertes', icon: AlertTriangle, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      { href: '/pilotage/mon-equipe', label: 'Mon équipe', icon: UsersRound, roles: ['ADMIN', 'DIRECTEUR_REGIONAL'] },
      // Rapports d'activité : consultés depuis la fiche d'un chef de secteur (Mon équipe).
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

/** Fond du menu ABC Pilot : violet nuit uni. */
const FOND_MENU: React.CSSProperties = {
  backgroundColor: '#120D24',
};

function isActive(pathname: string, href: string) {
  return href === '/pilotage' ? pathname === '/pilotage' : pathname === href || pathname.startsWith(`${href}/`);
}

const SWITCH_ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

export function SideMenu({ me, seliosPort }: { me: Me; seliosPort: string }) {
  const pathname = usePathname();
  const canSwitch = SWITCH_ROLES.includes(me.role);
  const [switching, setSwitching] = useState(false);
  // AscendoPilot et GoBack : ouverture directe dans un nouvel onglet, sans animation.
  const goAscendo = () => window.open('https://ascendopilot.abcosmetique.com', '_blank', 'noopener');
  const goGoBack = () => window.open('https://goback.abcosmetique.com/', '_blank', 'noopener');
  // ABC Sales tourne sur le même serveur : on reprend l'hôte utilisé pour accéder à ABC Pilot.
  // L'animation de bascule joue d'abord, puis la navigation part (le voile reste jusqu'au déchargement).
  const goSelios = () => {
    if (switching) return;
    setSwitching(true);
    window.setTimeout(() => {
      window.location.href = `${window.location.protocol}//${window.location.hostname}:${seliosPort}`;
    }, 1100);
  };

  return (
    <aside className="dark sticky top-0 z-20 flex h-screen w-64 shrink-0 flex-col border-r border-navy-700 bg-navy-950 text-neutral-100" style={FOND_MENU}>
      {switching ? (
        <UniverseSwitchOverlay
          fromSrc="/logo-abc-pilot.png"
          toSrc="/logo-abc-sales.png"
          toName="ABC Sales"
        />
      ) : null}
      {/* Marque */}
      <Link href="/pilotage" className="flex items-center justify-center px-4 py-5">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo-salespilot.png" alt="SalesPilot ABC" className="h-auto w-full max-w-[224px]" />
      </Link>

      {/* Sélecteur d'univers & d'outils (façon Slack) */}
      <UniverseSwitcher
        actuel={{ logo: '/logo-abc-pilot.png', nom: 'ABC Pilot', sousTitre: 'Force commerciale' }}
        items={[
          ...(canSwitch
            ? [{
                logo: '/logo-abc-sales.png',
                nom: 'ABC Sales',
                description: 'Force de vente — promoteurs',
                onClick: goSelios,
              }]
            : []),
        ]}
      />

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
                        className={`group flex items-center gap-2.5 rounded-lg border-l-4 border-transparent px-3 py-2.5 text-[15px] transition ${
                          active
                            ? 'bg-neutral-100 font-semibold text-neutral-900 dark:border-violet-500 dark:bg-violet-100 dark:text-violet-700'
                            : 'text-neutral-500 hover:bg-neutral-50 hover:text-neutral-900 dark:text-white dark:hover:bg-white/10'
                        }`}
                      >
                        {/* Surbrillance or translucide au survol ; texte blanc et icônes mauves conservés. */}
                        <Icon size={19} className={`shrink-0 ${active ? 'text-brand' : 'text-neutral-400 dark:text-white'}`} />
                        {c.label}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}

        {/* Outils externes : s'ouvrent dans un nouvel onglet (animation de transition conservée). */}
        <div className="mt-5">
          <p className="flex items-center gap-3 px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-400 dark:text-indigo-200/80">
            <span>Outils complémentaires</span>
            <span aria-hidden className="h-px flex-1 bg-white/15" />
          </p>
          <ul className="flex flex-col gap-2">
            {[
              { label: 'AscendoPilot', detail: 'Statistiques et analyses', icon: BarChart3, tuile: 'bg-blue-900 text-sky-300', onClick: goAscendo },
              { label: 'GoBack', detail: 'Gestion des litiges', icon: ClipboardCheck, tuile: 'bg-violet-800 text-white', onClick: goGoBack },
            ].map(({ label, detail, icon: Icon, tuile, onClick }) => (
              <li key={label}>
                <button
                  type="button"
                  onClick={onClick}
                  className="group flex w-full items-center gap-3 rounded-xl border border-white/15 bg-white/5 px-2 py-2 text-left transition hover:bg-white/10"
                >
                  <span className={`inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${tuile}`}>
                    <Icon size={20} aria-hidden />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[15px] font-semibold leading-tight text-white">{label}</span>
                    <span className="block truncate text-xs text-white/60">{detail}</span>
                  </span>
                  <ExternalLink size={14} className="shrink-0 text-white/70" aria-hidden />
                </button>
              </li>
            ))}
          </ul>
        </div>
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
