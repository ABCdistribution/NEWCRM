import type { Role } from './api';

/**
 * Fiches « Mon équipe » que la carte d'accueil (et tout lien interne) peut proposer à un rôle.
 *
 * Un lien vers une page que le rôle n'a pas le droit d'ouvrir mène à l'écran « Accès refusé » : on n'affiche
 * donc le lien que si la page de destination accepte le rôle, sinon le nom reste du texte simple.
 * Ces listes REPRENNENT les gardes `requireRole` des deux pages (le test `carte-fiches.test.ts` lit les
 * pages et échoue si elles divergent) ; elles ne remplacent pas ces gardes, qui restent la vraie protection,
 * et l'API filtre toujours le périmètre.
 */

/** Fiche d'un chef de secteur : (app)/(direction)/mon-equipe/[id]. DIRECTION en est volontairement exclue. */
const FICHE_CHEF_SECTEUR: readonly Role[] = ['DIRECTEUR_REGIONAL', 'ADMIN'];

/** Fiche d'un promoteur : (app)/(direction)/mon-equipe/promoteur/[id]. DIRECTION en est volontairement exclue. */
const FICHE_PROMOTEUR: readonly Role[] = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN'];

export function peutOuvrirFicheChefSecteur(role: Role): boolean {
  return FICHE_CHEF_SECTEUR.includes(role);
}

export function peutOuvrirFichePromoteur(role: Role): boolean {
  return FICHE_PROMOTEUR.includes(role);
}
