'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home,
  Store,
  Package,
  Footprints,
  Route,
  ShoppingCart,
  ShieldAlert,
  BadgePercent,
  LogOut,
  Menu,
  X,
  ArrowLeftRight,
  ExternalLink,
  BarChart3,
  ClipboardCheck,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { NotificationsBell } from './notifications-bell';
import { UniverseSwitchOverlay } from './universe-switch-overlay';
import type { Me, NotificationItem } from '@/lib/api';
import { UniverseSwitcher } from './universe-switcher';

type Leaf = { href: string; label: string; icon: LucideIcon; roles?: string[] };
type Section = { label: string | null; children: Leaf[] };

/**
 * Navigation ABC Sales. Les entrées portent le libellé « Les … » pour tous les rôles ; seul le titre de
 * section change (« Mon terrain » pour un commercial). Les données affichées restent, elles, limitées au
 * périmètre de l'utilisateur par l'API. Libellés toujours visibles (pas de survol nécessaire).
 */
/** Fond du menu ABC Sales : bleu marine uni. */
const FOND_MENU: React.CSSProperties = {
  backgroundColor: '#050F33',
};

function sections(role: string): Section[] {
  const moi = role === 'COMMERCIAL';
  return [
    {
      label: null,
      children: [
        { href: '/', label: 'Accueil', icon: Home },
      ],
    },
    {
      label: moi ? 'Mon terrain' : 'Terrain',
      // L'agenda / les tournées ne vivent que sur l'app mobile — pas d'entrée web.
      children: [
        { href: '/clients', label: 'Les magasins', icon: Store },
        { href: '/visites', label: 'Les visites', icon: Footprints },
        { href: '/commandes', label: 'Les commandes', icon: ShoppingCart },
        // Planification des visites — encadrement uniquement (déplacée depuis ABC Pilot).
        { href: '/planification', label: 'Planification visites', icon: Route, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'] },
      ],
    },
    {
      label: 'Catalogue',
      children: [
        { href: '/produits', label: 'Les produits', icon: Package },
        { href: '/promos', label: 'Les promos / PEM', icon: BadgePercent },
        { href: '/qualite', label: 'Qualité & rappels', icon: ShieldAlert },
      ],
    },
  ];
}

function isActive(pathname: string, href: string) {
  return href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(`${href}/`);
}

/** Rôles encadrement autorisés à basculer vers l'espace pilotage (miroir du bouton côté ABC Pilot). */
const SWITCH_ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** Marque de la plateforme (SalesPilot ABC) : grande dans la sidebar, compacte dans la barre mobile. */
function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/" className={compact ? 'inline-flex items-center' : 'flex w-full items-center justify-center py-2'}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/logo-salespilot.png" alt="SalesPilot ABC" className={compact ? 'h-9 w-auto' : 'h-auto w-full max-w-[224px]'} />
    </Link>
  );
}

/** Contenu du menu (navigation + pied utilisateur), partagé sidebar / tiroir mobile. */
function MenuPanel({
  me,
  notifications,
  heliosPort,
}: {
  me: Me;
  notifications: { nonLues: number; items: NotificationItem[] };
  heliosPort: string;
}) {
  const pathname = usePathname();
  const canSwitch = SWITCH_ROLES.includes(me.role);
  const [switching, setSwitching] = useState(false);
  // ABC Pilot tourne sur le même serveur : on reprend l'hôte utilisé pour accéder à ABC Sales.
  // L'animation de bascule joue d'abord, puis la navigation part (le voile reste jusqu'au déchargement).
  const goHelios = () => {
    if (switching) return;
    setSwitching(true);
    window.setTimeout(() => {
      window.location.href = `${window.location.protocol}//${window.location.hostname}:${heliosPort}`;
    }, 1100);
  };
  // AscendoPilot et GoBack : ouverture directe dans un nouvel onglet, sans animation.
  const goAscendo = () => window.open('https://ascendopilot.abcosmetique.com', '_blank', 'noopener');
  const goGoBack = () => window.open('https://goback.abcosmetique.com/', '_blank', 'noopener');

  return (
    <>
      {switching ? (
        <UniverseSwitchOverlay
          fromSrc="/logo-abc-sales.png"
          toSrc="/logo-abc-pilot.png"
          toName="ABC Pilot"
        />
      ) : null}
      {/* Sélecteur d'univers & d'outils (façon Slack) */}
      <UniverseSwitcher
        actuel={{ logo: '/logo-abc-sales.png', nom: 'ABC Sales', sousTitre: 'Force de vente' }}
        items={[
          ...(canSwitch
            ? [{
                logo: '/logo-abc-pilot.png',
                nom: 'ABC Pilot',
                description: 'Force commerciale',
                onClick: goHelios,
              }]
            : []),
        ]}
      />

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 pb-4">
        {sections(me.role).map((section, i) => {
          const children = section.children.filter((c) => !c.roles || c.roles.includes(me.role));
          if (children.length === 0) return null;
          return (
            <div key={section.label ?? i} className={i > 0 ? 'mt-5' : ''}>
              {section.label ? (
                <p className="px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-400 dark:text-white/60">
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
                            ? 'bg-neutral-100 font-semibold text-neutral-900 dark:bg-[#1C347D] dark:text-white'
                            : 'text-neutral-500 hover:bg-neutral-50 hover:text-neutral-900 dark:text-white dark:hover:bg-accent/20'
                        }`}
                      >
                        {/* Surbrillance cyan translucide au survol ; texte blanc et icônes lavande conservés. */}
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

        {/* Outils externes : s'ouvrent dans un nouvel onglet (animation de transition conservée). */}
        <div className="mt-5">
          <p className="px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-400 dark:text-white/60">
            Outils complémentaires
          </p>
          <ul className="flex flex-col gap-0.5">
            {[
              { label: 'AscendoPilot', detail: 'Statistiques et analyses', icon: BarChart3, onClick: goAscendo },
              { label: 'GoBack', detail: 'Gestion des litiges', icon: ClipboardCheck, onClick: goGoBack },
            ].map(({ label, detail, icon: Icon, onClick }) => (
              <li key={label}>
                <button
                  type="button"
                  onClick={onClick}
                  className="group flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left transition hover:bg-white/10"
                >
                  <span className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-navy-800 text-sky-300">
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
          <NotificationsBell nonLues={notifications.nonLues} items={notifications.items} />
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
    </>
  );
}

export function SideMenu({
  me,
  notifications,
  heliosPort,
}: {
  me: Me;
  notifications: { nonLues: number; items: NotificationItem[] };
  heliosPort: string;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // Le tiroir se referme à chaque navigation (clic sur un lien du menu).
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  // Échap ferme le tiroir ; le fond de page ne défile pas tant qu'il est ouvert.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open]);

  const surface =
    'dark border-navy-700 bg-nav text-neutral-100';

  return (
    <>
      {/* ≥ md : sidebar permanente (comportement historique). */}
      <aside className={`sticky top-0 z-20 hidden h-screen w-64 shrink-0 flex-col border-r md:flex ${surface}`} style={FOND_MENU}>
        <div className="px-4 py-4">
          <Brand />
        </div>
        <MenuPanel me={me} notifications={notifications} heliosPort={heliosPort} />
      </aside>

      {/* < md : barre supérieure avec hamburger. */}
      <header className={`sticky top-0 z-20 flex items-center gap-2 border-b px-3 py-2.5 md:hidden ${surface}`} style={FOND_MENU}>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="rounded-lg p-2 text-neutral-600 transition hover:bg-neutral-100 dark:text-white dark:hover:bg-accent/20"
          aria-label="Ouvrir le menu"
          aria-expanded={open}
        >
          <Menu size={22} />
        </button>
        <div className="flex-1">
          <Brand compact />
        </div>
        <NotificationsBell nonLues={notifications.nonLues} items={notifications.items} />
      </header>

      {/* < md : tiroir coulissant + voile de fond. */}
      {open ? (
        <div className="fixed inset-0 z-40 md:hidden" role="dialog" aria-modal="true" aria-label="Menu principal">
          <button
            type="button"
            className="absolute inset-0 bg-black/50"
            aria-label="Fermer le menu"
            onClick={() => setOpen(false)}
          />
          <div className={`absolute inset-y-0 left-0 flex w-72 max-w-[85vw] flex-col border-r shadow-xl ${surface}`} style={FOND_MENU}>
            <div className="flex items-center justify-between px-4 py-4">
              <Brand />
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="rounded-lg p-2 text-neutral-500 transition hover:bg-neutral-100 dark:text-white dark:hover:bg-accent/20"
                aria-label="Fermer le menu"
              >
                <X size={20} />
              </button>
            </div>
            <MenuPanel me={me} notifications={notifications} heliosPort={heliosPort} />
          </div>
        </div>
      ) : null}
    </>
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
