'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Montserrat } from 'next/font/google';
import {
  Home,
  Newspaper,
  Store,
  Package,
  Footprints,
  CalendarDays,
  Route,
  ShoppingCart,
  ShieldAlert,
  BadgePercent,
  LogOut,
  Menu,
  X,
  type LucideIcon,
} from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { NotificationsBell } from './notifications-bell';
import type { Me, NotificationItem } from '@/lib/api';

/** Police du mot-symbole « ABC » en tête de menu (aspect logo). */
const policeLogo = Montserrat({ subsets: ['latin'], weight: '800' });

type Leaf = { href: string; label: string; icon: LucideIcon; roles?: string[] };
type Section = { label: string | null; children: Leaf[] };

/**
 * Navigation ABC Sales. Les entrées portent le libellé « Les … » pour tous les rôles ; seul le titre de
 * section change (« Mon terrain » pour un commercial). Les données affichées restent, elles, limitées au
 * périmètre de l'utilisateur par l'API. Libellés toujours visibles (pas de survol nécessaire).
 */
/** Fond du menu Promoteurs : bleu encre uni (#0B2545, couleur de la maquette mobile). */
const FOND_MENU: React.CSSProperties = {
  backgroundColor: '#0B2545',
};

function sections(role: string): Section[] {
  const moi = role === 'COMMERCIAL';
  return [
    {
      label: null,
      children: [
        { href: '/', label: 'Accueil', icon: Home },
        { href: '/news', label: 'Les News', icon: Newspaper },
      ],
    },
    {
      label: moi ? 'Mon terrain' : 'Terrain',
      // Pas d'agenda web (/agenda reste une page « bientôt »). Le promoteur consulte son planning en
      // lecture seule (/tournees) ; la planification elle-même se fait sur l'app mobile / par l'encadrement.
      children: [
        { href: '/tournees', label: 'Mon planning', icon: CalendarDays, roles: ['COMMERCIAL'] },
        { href: '/clients', label: 'Les clients', icon: Store },
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

/** Marque de la plateforme (SalesPilot ABC) : grande dans la sidebar, compacte dans la barre mobile. */
function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/" className={`focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent ${compact ? 'inline-flex items-center gap-2' : 'flex w-full flex-col items-center justify-center gap-1.5 py-2'}`}>
      <span className={`${policeLogo.className} ${compact ? 'text-2xl' : 'text-5xl'} select-none font-extrabold leading-none tracking-[0.18em] text-white`} aria-label="ABC">ABC</span>
      <span className="text-xs font-medium text-white/70">Promoteurs</span>
    </Link>
  );
}

/** Contenu du menu (navigation + pied utilisateur), partagé sidebar / tiroir mobile. */
function MenuPanel({
  me,
  notifications,
}: {
  me: Me;
  notifications: { nonLues: number; items: NotificationItem[] };
}) {
  const pathname = usePathname();

  return (
    <>
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
}: {
  me: Me;
  notifications: { nonLues: number; items: NotificationItem[] };
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
        <MenuPanel me={me} notifications={notifications} />
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
            <MenuPanel me={me} notifications={notifications} />
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
