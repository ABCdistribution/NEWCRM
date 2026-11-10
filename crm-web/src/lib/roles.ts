import { cache, createElement, type ReactElement } from 'react';
import { headers } from 'next/headers';
import { redirect, unstable_rethrow } from 'next/navigation';
import { AccesRefuse } from '@/components/acces-refuse';
import { projeterMe, serverFetch, type Me, type Role } from './api';
import { cheminInterneSur } from './chemin';

export type { Role };

/** Encadrement : accès à l'espace Direction commerciale (et aux écrans terrain). */
export const ENCADREMENT: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** Terrain : espace Promoteurs (ABC Sales). */
export const TERRAIN: readonly Role[] = ['COMMERCIAL', 'ADV'];

/** Tous les rôles connus de l'API. */
export const TOUS_ROLES: readonly Role[] = [...ENCADREMENT, ...TERRAIN, 'MARKETING'];

/**
 * Rôles qui ont accès aux commandes et aux visites : tous sauf le marketing (décision de l'utilisateur). Même liste que
 * `ROLES_COMMANDES_VISITES` de l'API, qui reste la vraie protection.
 */
export const ROLES_COMMANDES_VISITES: readonly Role[] = [...ENCADREMENT, ...TERRAIN];

/** Espaces de l'application : pilotent le thème (`data-espace`) et le menu. */
export type Espace = 'promoteurs' | 'direction';

export function estEncadrement(role: Role): boolean {
  return ENCADREMENT.includes(role);
}

/** Espace (thème + menu) d'un rôle. */
export function espaceDe(role: Role): Espace {
  if (estEncadrement(role)) return 'direction';
  if (TERRAIN.includes(role)) return 'promoteurs';
  // MARKETING : thème et menu de l'espace Promoteurs (bleu), sur décision de l'utilisateur ; ses accès restent ceux de
  // son rôle (aucun écran de pilotage : ils sont réservés à l'encadrement par la table ROUTES).
  return 'promoteurs';
}

/**
 * En-tête posé par le middleware : chemin demandé (avec sa requête). Les composants serveur ne connaissent pas
 * l'adresse courante ; ce chemin sert à revenir sur la page demandée après une reconnexion (`/login?from=…`).
 */
export const ENTETE_CHEMIN = 'x-crm-chemin';

/** L'API ne répond pas (arrêt, redémarrage, erreur 5xx, réponse illisible) : ce n'est PAS une déconnexion. */
export class ErreurServiceIndisponible extends Error {
  constructor() {
    super('Service momentanément indisponible');
    this.name = 'ErreurServiceIndisponible';
  }
}

/**
 * Message d'une action dont le contrôle de rôle (`exigerRole`) a levé : « service indisponible » quand l'API est en
 * panne (le rôle n'a pas été jugé : annoncer un refus serait faux), `refus` dans tous les autres cas.
 * Usage : `catch (e) { return messageRefus(e, 'Accès refusé.'); }`
 */
export function messageRefus(e: unknown, refus: string): string {
  return e instanceof ErreurServiceIndisponible ? 'Service momentanément indisponible, réessayez dans un instant.' : refus;
}

/**
 * État de la session, d'après GET /auth/me :
 *  - `connecte`     : jeton valide, utilisateur connu ;
 *  - `absente`      : pas de jeton, jeton expiré ou refusé (401 / 403) → il faut se reconnecter ;
 *  - `indisponible` : API injoignable, 5xx ou réponse illisible → rien à conclure sur la session, ne PAS
 *                     renvoyer vers /login (le cookie est peut-être encore valable).
 */
export type Session = { etat: 'connecte'; me: Me } | { etat: 'absente' } | { etat: 'indisponible' };

/**
 * Lit la session auprès de l'API. Mise en cache par requête (React `cache`) : les layouts (app) et de groupe,
 * la page et les gardes partagent UN SEUL appel à /auth/me par rendu au lieu de trois.
 *
 * ATTENTION au `catch` : la lecture du cookie (`cookies()`, dans serverFetch) signale à Next que la page est DYNAMIQUE
 * en levant une exception interne. L'avaler (`catch` nu) ferait croire à une API indisponible au moment de la
 * génération statique : toutes les pages seraient prérendues avec l'écran « service indisponible » et le
 * `next build` échouerait. `unstable_rethrow` relance ces exceptions internes (rendu dynamique, redirection…).
 */
export const lireSession = cache(async (): Promise<Session> => {
  try {
    const res = await serverFetch('/auth/me');
    if (res.ok) {
      // Projection : l'API renvoie la ligne Prisma complète (photo en octets, secteurId…), dont rien ne doit
      // partir vers le navigateur. Un corps sans identifiant ni rôle est une anomalie de l'API, pas une déconnexion.
      const me = projeterMe(await res.json());
      return me ? { etat: 'connecte', me } : { etat: 'indisponible' };
    }
    if (res.status === 401 || res.status === 403) return { etat: 'absente' };
    return { etat: 'indisponible' };
  } catch (e) {
    unstable_rethrow(e);
    return { etat: 'indisponible' };
  }
});

/**
 * Adresse de connexion qui ramène sur la page demandée : `/login?from=<chemin>`. Le chemin vient du middleware
 * (en-tête ENTETE_CHEMIN, réécrit à chaque requête) et reste assaini par `cheminInterneSur` ; sans chemin
 * exploitable (ou si c'est « / »), simplement `/login`.
 */
export async function urlLogin(): Promise<string> {
  const chemin = cheminInterneSur((await headers()).get(ENTETE_CHEMIN));
  return chemin === '/' ? '/login' : `/login?from=${encodeURIComponent(chemin)}`;
}

/**
 * Garde serveur d'une page. Pas de session → redirection vers /login (qui ramène ensuite sur la page demandée).
 * Rôle non autorisé → renvoie l'écran « Accès refusé » à afficher à la place de la page.
 * Rôle autorisé → renvoie l'utilisateur.
 * API indisponible → lève ErreurServiceIndisponible (page d'erreur, jamais de redirection vers /login).
 *
 * Usage : const acces = await requireRole(ROLES); if (acces.refuse) return acces.refuse;
 *
 * ATTENTION : un layout ne protège pas les pages ni les Server Actions : chaque page [id] / action /
 * route handler doit rappeler requireRole (ou exigerRole dans une action) ou s'appuyer sur l'API.
 */
export async function requireRole(
  roles: readonly Role[],
): Promise<{ me: Me; refuse: null } | { me: Me; refuse: ReactElement }> {
  const session = await lireSession();
  if (session.etat === 'absente') redirect(await urlLogin());
  if (session.etat === 'indisponible') throw new ErreurServiceIndisponible();
  const { me } = session;
  if (!roles.includes(me.role)) {
    return { me, refuse: createElement(AccesRefuse) };
  }
  return { me, refuse: null };
}

/**
 * Variante pour les Server Actions : renvoie l'utilisateur si son rôle est autorisé,
 * sinon lève une erreur « Accès refusé » (à intercepter pour renvoyer un message à l'utilisateur).
 * Pas de session : lève aussi (une action ne redirige pas proprement vers /login).
 * API indisponible : lève ErreurServiceIndisponible (distincte, pour ne pas annoncer un faux refus).
 */
export async function exigerRole(roles: readonly Role[]): Promise<Me> {
  const session = await lireSession();
  if (session.etat === 'indisponible') throw new ErreurServiceIndisponible();
  if (session.etat !== 'connecte' || !roles.includes(session.me.role)) throw new Error('Accès refusé');
  return session.me;
}
