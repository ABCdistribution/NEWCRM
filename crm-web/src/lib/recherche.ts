// Recherche générale (bandeau du haut) : types, liens vers les pages et lecture défensive de la réponse de l'API.
// Fonctions pures, sans réseau : importables côté serveur comme côté client, testées à part.
import type { Role } from './api';
import { peutOuvrirFicheChefSecteur, peutOuvrirFichePromoteur } from './carte-fiches';

export type TypeResultat = 'clients' | 'commandes' | 'visites' | 'collaborateurs' | 'prospects' | 'produits';

export type Resultat = {
  id: string;
  titre: string;
  detail: string | null;
  /** Collaborateurs : rôle, qui décide de la fiche à ouvrir. */
  role?: Role;
  /** Visites : client concerné. */
  clientId?: string | null;
  /** Visites et produits : texte passé à la liste de destination (`?search=`). */
  recherche?: string;
};

export type GroupeResultats = { type: TypeResultat; total: number; items: Resultat[] };
export type RechercheGlobale = { q: string; groupes: GroupeResultats[] };

/** Ordre d'affichage des familles et leur titre. */
export const FAMILLES: readonly { type: TypeResultat; libelle: string }[] = [
  { type: 'clients', libelle: 'Clients' },
  { type: 'commandes', libelle: 'Commandes' },
  { type: 'visites', libelle: 'Visites' },
  { type: 'collaborateurs', libelle: 'Collaborateurs' },
  { type: 'prospects', libelle: 'Prospects' },
  { type: 'produits', libelle: 'Produits' },
];

const TYPES = new Set<string>(FAMILLES.map((f) => f.type));
const ROLES = new Set<string>(['COMMERCIAL', 'CHEF_SECTEUR', 'ADMIN', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADV', 'MARKETING']);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Longueurs maximales : la réponse vient de l'API mais s'affiche telle quelle, on la borne. */
const MAX_TEXTE = 160;
const MAX_LIGNES = 10;

const texte = (v: unknown, max = MAX_TEXTE): string | null =>
  typeof v === 'string' && v.trim() ? v.trim().slice(0, max) : null;

/**
 * Lecture défensive de la réponse de `GET /search` : seules les familles connues, les lignes dont l'id est un UUID
 * (il finit dans une adresse de page) et les champs attendus sont conservés. Toute autre forme donne « aucun résultat ».
 */
export function assainirRecherche(brut: unknown, q: string): RechercheGlobale {
  const groupes: GroupeResultats[] = [];
  const liste = (brut as { groupes?: unknown } | null)?.groupes;
  if (!Array.isArray(liste)) return { q, groupes };

  for (const g of liste) {
    const type = (g as { type?: unknown })?.type;
    if (typeof type !== 'string' || !TYPES.has(type) || groupes.some((x) => x.type === type)) continue;
    const bruts = (g as { items?: unknown }).items;
    if (!Array.isArray(bruts)) continue;

    const items: Resultat[] = [];
    for (const it of bruts.slice(0, MAX_LIGNES)) {
      const o = it as Record<string, unknown> | null;
      const id = texte(o?.id, 64);
      const titre = texte(o?.titre);
      if (!id || !UUID.test(id) || !titre) continue;
      const clientId = texte(o?.clientId, 64);
      const role = typeof o?.role === 'string' && ROLES.has(o.role) ? (o.role as Role) : undefined;
      const recherche = texte(o?.recherche, 80);
      items.push({
        id,
        titre,
        detail: texte(o?.detail),
        ...(role ? { role } : {}),
        ...(clientId && UUID.test(clientId) ? { clientId } : {}),
        ...(recherche ? { recherche } : {}),
      });
    }
    if (items.length === 0) continue;
    const total = Number((g as { total?: unknown }).total);
    groupes.push({
      type: type as TypeResultat,
      total: Number.isInteger(total) && total >= items.length ? total : items.length,
      items,
    });
  }
  // Ordre fixe des familles, quel que soit celui de la réponse.
  groupes.sort((a, b) => FAMILLES.findIndex((f) => f.type === a.type) - FAMILLES.findIndex((f) => f.type === b.type));
  return { q, groupes };
}

const enc = encodeURIComponent;

/**
 * Page à ouvrir pour un résultat, ou null quand le rôle n'a pas de page où l'envoyer (le résultat reste affiché,
 * sans lien : un lien vers une page interdite mènerait à « Accès refusé »). Les pages gardent leurs propres règles.
 */
export function lienResultat(type: TypeResultat, r: Resultat, role: Role): string | null {
  switch (type) {
    case 'clients':
      return `/clients/${enc(r.id)}`;
    case 'commandes':
      return `/commandes/${enc(r.id)}`;
    case 'visites':
      // Pas de page de détail d'une visite : la liste des visites, filtrée sur le client.
      return r.recherche ? `/visites?search=${enc(r.recherche)}` : null;
    case 'collaborateurs':
      if (r.role === 'COMMERCIAL') return peutOuvrirFichePromoteur(role) ? `/mon-equipe/promoteur/${enc(r.id)}` : null;
      if (r.role === 'CHEF_SECTEUR') return peutOuvrirFicheChefSecteur(role) ? `/mon-equipe/${enc(r.id)}` : null;
      return null;
    case 'prospects':
      return `/prospects/${enc(r.id)}`;
    case 'produits':
      return r.recherche ? `/produits?search=${enc(r.recherche)}` : null;
  }
}

/** Liste complète d'une famille (« Voir les N résultats »), quand une page de liste sait filtrer sur le texte saisi. */
export function lienTous(type: TypeResultat, q: string): string | null {
  switch (type) {
    case 'clients':
      return `/clients?vue=portefeuille&search=${enc(q)}`;
    case 'commandes':
      return `/commandes?search=${enc(q)}`;
    case 'visites':
      return `/visites?search=${enc(q)}`;
    case 'produits':
      return `/produits?search=${enc(q)}`;
    default:
      return null;
  }
}
