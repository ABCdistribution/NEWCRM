'use client';

import { LogOut } from 'lucide-react';
import { logout } from '@/lib/auth-actions';
import type { Me, NotificationItem } from '@/lib/api';
import { libelleCompteurs, niveauObjectif } from '@/lib/activite';
import type { Activite } from '@/lib/carte';
import { Avatar } from './avatar';
import { ROLE_LABELS } from './badges';
import { initiales } from './equipe-ui';
import { NotificationsBell } from './notifications-bell';
import { RechercheGlobale } from './recherche-globale';

/** Champs de l'utilisateur utilisés par le bandeau : seuls ceux-là sont sérialisés vers le navigateur. */
export type BandeauUser = Pick<Me, 'id' | 'displayName' | 'poste' | 'role'>;
type Notifs = { nonLues: number; items: NotificationItem[] } | null;

/** Teinte de la ligne d'activité selon l'atteinte de l'objectif (neutre sans objectif) ; le pourcentage reste écrit. */
const COULEUR_TAUX = { bon: 'text-emerald-800', moyen: 'text-amber-800', bas: 'text-red-700', aucun: 'text-neutral-500' } as const;

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

/**
 * Bandeau du haut, au-dessus du contenu : recherche générale à gauche ; à droite la cloche de notifications,
 * l'utilisateur connecté (photo, nom, poste ou rôle) et la déconnexion. Fixé en haut à partir de `md` ; sur mobile le
 * hamburger du menu reste au-dessus et le bandeau défile avec la page.
 * `notifications` : boîte de réception de l'utilisateur (tous les rôles) ; la cloche n'est omise que si `null`.
 * `activite` : activité du mois de l'utilisateur (chef de secteur, directeur régional), écrite sous son nom ; null sinon.
 */
export function Bandeau({ me, notifications, activite = null }: { me: BandeauUser; notifications: Notifs; activite?: Activite | null }) {
  return (
    <header className="border-b border-neutral-200 bg-white md:sticky md:top-0 md:z-30">
      <div className="mx-auto flex max-w-[88rem] items-center gap-3 px-4 py-3 sm:px-6">
        <div className="min-w-0 max-w-2xl flex-1">
          <RechercheGlobale role={me.role} />
        </div>

        <div className="ml-auto flex shrink-0 items-center gap-1.5 sm:gap-2.5">
          {notifications ? <NotificationsBell nonLues={notifications.nonLues} items={notifications.items} /> : null}

          <div className="flex items-center gap-2.5">
            <Avatar src={`/avatar/${encodeURIComponent(me.id)}`} initials={initiales(me.displayName)} size={40} />
            <div className="hidden min-w-0 sm:block">
              <p className="max-w-44 truncate text-sm font-semibold leading-tight">{me.displayName}</p>
              <p className="max-w-44 truncate text-xs leading-tight text-neutral-500">
                {me.poste ?? ROLE_LABELS[me.role] ?? ''}
              </p>
              {activite ? (
                <p
                  className={`mt-0.5 hidden whitespace-nowrap text-xs leading-tight lg:block ${COULEUR_TAUX[niveauObjectif(activite.tauxPct)]}`}
                  aria-label={`Mon activité du mois : ${libelleCompteurs(activite).join(', ')}`}
                >
                  {libelleCompteurs(activite).join(' · ')}
                </p>
              ) : null}
            </div>
          </div>

          <form action={logout}>
            <button
              type="submit"
              className={`${FOCUS} rounded-lg p-2 text-neutral-600 transition hover:bg-red-50 hover:text-red-700`}
              aria-label="Déconnexion"
              title="Déconnexion"
            >
              <LogOut size={18} aria-hidden />
            </button>
          </form>
        </div>
      </div>
    </header>
  );
}
