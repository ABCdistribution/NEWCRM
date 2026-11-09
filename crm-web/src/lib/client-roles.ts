import { ENCADREMENT, TERRAIN, type Role } from './roles';

/**
 * Rôles autorisés à éditer la fiche client (contacts, notes, périodicité) : terrain et encadrement
 * (l'encadrement garde l'accès aux écrans terrain). MARKETING est exclu.
 * ADV est inclus parce qu'il est classé TERRAIN : son périmètre est « à définir plus tard » (décision métier
 * en attente, rien n'est inventé ici).
 *
 * Hors fichier 'use server' (qui ne peut exporter que des fonctions asynchrones) : la même liste sert aux
 * Server Actions (exigerRole) et à la page (masquage des boutons d'édition). Module à n'importer que côté
 * serveur. Le périmètre (portefeuille, secteur, région) reste filtré par l'API.
 */
export const EDITEURS_CLIENT: readonly Role[] = [...TERRAIN, ...ENCADREMENT];
