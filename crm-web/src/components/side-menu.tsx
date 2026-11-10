'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Montserrat } from 'next/font/google';
import { LogOut, Menu, X } from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import { Avatar } from './avatar';
import { NotificationsBell } from './notifications-bell';
import type { Me, NotificationItem } from '@/lib/api';
import type { MenuSection } from '@/lib/menu';

/** Champs de l'utilisateur utilisés par le menu : seuls ceux-là sont sérialisés vers le navigateur. */
export type MenuUser = Pick<Me, 'id' | 'displayName' | 'poste' | 'role'>;

/** Police du mot-symbole « ABC » en tête de menu (aspect logo). */
const policeLogo = Montserrat({ subsets: ['latin'], weight: '800' });

type Espace = 'promoteurs' | 'direction';
type Notifs = { nonLues: number; items: NotificationItem[] } | null;

const SOUS_TITRE: Record<Espace, string> = {
  promoteurs: 'Promoteurs',
  direction: 'Direction commerciale',
};

// Menu blanc : l'anneau de focus prend la couleur principale de l'espace (l'accent, pâle en violet, ne contraste pas assez sur blanc).
const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

function isActive(pathname: string, href: string) {
  return href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(`${href}/`);
}

/** Marque : grande dans la sidebar, compacte dans la barre mobile. */
function Brand({ espace, compact = false }: { espace: Espace; compact?: boolean }) {
  return (
    <Link
      href="/"
      className={`${FOCUS} ${compact ? 'inline-flex items-center gap-2' : 'flex w-full flex-col items-center justify-center gap-1.5 py-2'}`}
    >
      <span
        className={`${policeLogo.className} ${compact ? 'text-2xl' : 'text-5xl'} select-none font-extrabold leading-none tracking-[0.18em] text-brand`}
        aria-label="ABC"
      >
        ABC
      </span>
      <span className="text-xs font-medium text-neutral-500">{SOUS_TITRE[espace]}</span>
    </Link>
  );
}

/** Contenu du menu (navigation + pied utilisateur), partagé sidebar / tiroir mobile. */
function MenuPanel({ me, sections, notifications }: { me: MenuUser; sections: MenuSection[]; notifications: Notifs }) {
  const pathname = usePathname();

  return (
    <>
      <nav aria-label="Navigation principale" className="flex-1 overflow-y-auto px-3 pb-4">
        {sections.map((section, i) => (
          <div key={section.label ?? i} className={i > 0 ? 'mt-5' : ''}>
            {section.label ? (
              <p className="flex items-center gap-3 px-3 pb-1.5 text-xs font-semibold uppercase tracking-wider text-neutral-500">
                <span>{section.label}</span>
                <span aria-hidden className="h-px flex-1 bg-neutral-200" />
              </p>
            ) : null}
            <ul className="flex flex-col gap-0.5">
              {section.items.map((c) => {
                const active = isActive(pathname, c.href);
                return (
                  <li key={c.href}>
                    <Link
                      href={c.href}
                      aria-current={active ? 'page' : undefined}
                      className={`${FOCUS} group flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-[15px] transition ${
                        active ? 'bg-brand/10 font-semibold text-brand' : 'text-neutral-700 hover:bg-neutral-100'
                      }`}
                    >
                      <span className="shrink-0">{c.icon}</span>
                      {c.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      {/* Utilisateur + déconnexion */}
      <div className="border-t border-neutral-200 p-3">
        <div className="flex items-center gap-2.5 px-1">
          <Avatar src={`/avatar/${encodeURIComponent(me.id)}`} initials={initials(me.displayName)} size={36} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{me.displayName}</p>
            <p className="truncate text-xs text-neutral-500">{me.poste ?? ROLE_LABELS[me.role] ?? ''}</p>
          </div>
        </div>
        <div className="mt-2 flex items-center justify-end gap-1 px-1">
          {notifications ? <NotificationsBell nonLues={notifications.nonLues} items={notifications.items} /> : null}
          <form action={logout}>
            <button
              type="submit"
              className={`${FOCUS} rounded-lg p-2 text-neutral-600 transition hover:bg-red-50 hover:text-red-700`}
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

/**
 * Menu latéral unique. Sections et entrées viennent de `construireMenu` (table ROUTES) ;
 * `notifications` : boîte de réception de l'utilisateur (tous les rôles) ; la cloche n'est omise que si `null`.
 */
export function SideMenu({
  me,
  espace,
  sections,
  notifications,
}: {
  me: MenuUser;
  espace: Espace;
  sections: MenuSection[];
  notifications: Notifs;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // Le tiroir se referme à chaque navigation.
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

  // Menu : fond blanc plein (le fond de la page, lui, est le gris très clair du thème).
  const surface = 'border-neutral-200 bg-white';

  return (
    <>
      {/* ≥ md : sidebar permanente. */}
      <aside className={`sticky top-0 z-20 hidden h-screen w-64 shrink-0 flex-col border-r md:flex ${surface}`}>
        <div className="px-4 py-4">
          <Brand espace={espace} />
        </div>
        <MenuPanel me={me} sections={sections} notifications={notifications} />
      </aside>

      {/* < md : barre supérieure avec hamburger. */}
      <header className={`sticky top-0 z-20 flex items-center gap-2 border-b px-3 py-2.5 md:hidden ${surface}`}>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className={`${FOCUS} rounded-lg p-2 text-neutral-700 transition hover:bg-neutral-100`}
          aria-label="Ouvrir le menu"
          aria-expanded={open}
        >
          <Menu size={22} />
        </button>
        <div className="flex-1">
          <Brand espace={espace} compact />
        </div>
        {notifications ? <NotificationsBell nonLues={notifications.nonLues} items={notifications.items} /> : null}
      </header>

      {/* < md : tiroir coulissant + voile de fond. */}
      {open ? (
        <div className="fixed inset-0 z-40 md:hidden" role="dialog" aria-modal="true" aria-label="Menu principal">
          <button type="button" className="absolute inset-0 bg-black/50" aria-label="Fermer le menu" onClick={() => setOpen(false)} />
          <div className={`absolute inset-y-0 left-0 flex w-72 max-w-[85vw] flex-col border-r shadow-xl ${surface}`}>
            <div className="flex items-center justify-between px-4 py-4">
              <Brand espace={espace} />
              <button
                type="button"
                onClick={() => setOpen(false)}
                className={`${FOCUS} rounded-lg p-2 text-neutral-700 transition hover:bg-neutral-100`}
                aria-label="Fermer le menu"
              >
                <X size={20} />
              </button>
            </div>
            <MenuPanel me={me} sections={sections} notifications={notifications} />
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
