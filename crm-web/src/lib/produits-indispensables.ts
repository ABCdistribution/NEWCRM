/** Types et logique pure de l'administration des produits indispensables (liste par enseigne = centrale). */

export type CentraleAdmin = {
  id: string;
  code: string;
  nom: string;
  parentId: string | null;
  /** Magasins actifs rattachés directement à cette centrale (feuille de l'arbre d'achat). */
  nbClients: number;
};

export type ProduitIndispensable = {
  id: string;
  centraleId: string;
  articleId: string;
  ordre: number;
  article: {
    id: string;
    codeAs400: string;
    libelle: string;
    gencode: string | null;
    marque: { id: string; nom: string } | null;
  };
};

/** Article proposé par la recherche (sous-ensemble de la ligne de la liste du catalogue). */
export type ArticleTrouve = {
  id: string;
  codeAs400: string;
  libelle: string;
  gencode: string | null;
  actif: boolean;
  marque: { nom: string } | null;
};

export const ORDRE_MAX = 100000;
export const RECHERCHE_MIN = 2;
export const RECHERCHE_MAX = 80;
export const DEPLACEMENTS_MAX = 500;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function estUuid(valeur: string): boolean {
  return UUID.test(valeur);
}

/** Entier de 0 à ORDRE_MAX (borne du DTO de l'API), ou null. */
export function ordreValide(valeur: unknown): number | null {
  const n = typeof valeur === 'string' && valeur.trim() !== '' ? Number(valeur) : valeur;
  if (typeof n !== 'number' || !Number.isInteger(n) || n < 0 || n > ORDRE_MAX) return null;
  return n;
}

/** Texte de recherche nettoyé (espaces compactés, borné), ou null s'il est trop court. */
export function texteRecherche(brut: unknown): string | null {
  const texte = String(brut ?? '').trim().replace(/\s+/g, ' ').slice(0, RECHERCHE_MAX);
  return texte.length >= RECHERCHE_MIN ? texte : null;
}

/** Regroupe les lignes par enseigne, chaque liste restant dans l'ordre reçu (déjà trié par l'API). */
export function grouperParCentrale(lignes: readonly ProduitIndispensable[]): Map<string, ProduitIndispensable[]> {
  const groupes = new Map<string, ProduitIndispensable[]>();
  for (const ligne of lignes) {
    const liste = groupes.get(ligne.centraleId);
    if (liste) liste.push(ligne);
    else groupes.set(ligne.centraleId, [ligne]);
  }
  return groupes;
}

/** Position proposée à un nouveau produit : à la suite des existants. */
export function prochainOrdre(liste: readonly Pick<ProduitIndispensable, 'ordre'>[]): number {
  if (liste.length === 0) return 0;
  return Math.min(ORDRE_MAX, Math.max(...liste.map((l) => l.ordre)) + 1);
}

/** Identifiants des articles déjà présents (pour éviter les doublons dans la recherche). */
export function articlesPresents(liste: readonly Pick<ProduitIndispensable, 'articleId'>[]): Set<string> {
  return new Set(liste.map((l) => l.articleId));
}

export type ChangementOrdre = { id: string; ordre: number };

/**
 * Déplace d'un cran la ligne `index` et renvoie les seules positions à enregistrer pour que la liste soit numérotée
 * 0..n-1 sans ex aequo (les positions saisies à 0 par défaut sont ainsi départagées). Liste vide si le déplacement
 * est impossible (bord de liste, index hors liste).
 */
export function changementsApresDeplacement(
  liste: readonly Pick<ProduitIndispensable, 'id' | 'ordre'>[],
  index: number,
  direction: 'haut' | 'bas',
): ChangementOrdre[] {
  const cible = direction === 'haut' ? index - 1 : index + 1;
  if (!Number.isInteger(index) || index < 0 || index >= liste.length || cible < 0 || cible >= liste.length) return [];
  const sequence = [...liste];
  [sequence[index], sequence[cible]] = [sequence[cible], sequence[index]];
  const changements: ChangementOrdre[] = [];
  sequence.forEach((ligne, position) => {
    if (ligne.ordre !== position) changements.push({ id: ligne.id, ordre: position });
  });
  return changements;
}

/** Contrôle d'une liste de changements reçue d'un formulaire (JSON) : renvoie la liste saine ou un message. */
export function lireChangements(
  brut: string,
): { changements: ChangementOrdre[]; erreur: null } | { changements: null; erreur: string } {
  let valeur: unknown;
  try {
    valeur = JSON.parse(brut);
  } catch {
    return { changements: null, erreur: 'Déplacement invalide.' };
  }
  if (!Array.isArray(valeur) || valeur.length === 0 || valeur.length > DEPLACEMENTS_MAX) {
    return { changements: null, erreur: 'Déplacement invalide.' };
  }
  const changements: ChangementOrdre[] = [];
  for (const element of valeur) {
    const objet = element && typeof element === 'object' ? (element as Record<string, unknown>) : null;
    const id = objet?.id;
    const ordre = objet ? ordreValide(objet.ordre) : null;
    if (typeof id !== 'string' || !estUuid(id) || ordre === null) {
      return { changements: null, erreur: 'Déplacement invalide.' };
    }
    changements.push({ id, ordre });
  }
  return { changements, erreur: null };
}

/** « Parent › Enfant » : nom de la centrale précédé de ses ancêtres (garde contre les cycles). */
export function cheminCentrale(centrale: CentraleAdmin, parId: ReadonlyMap<string, CentraleAdmin>): string {
  const noms = [centrale.nom];
  const vus = new Set([centrale.id]);
  let parent = centrale.parentId ? parId.get(centrale.parentId) : undefined;
  while (parent && !vus.has(parent.id)) {
    noms.unshift(parent.nom);
    vus.add(parent.id);
    parent = parent.parentId ? parId.get(parent.parentId) : undefined;
  }
  return noms.join(' › ');
}

const sansAccent = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

/**
 * Enseignes à afficher : par défaut celles qui ont des magasins ou déjà une liste (les autres ne servent à aucune
 * visite) ; `toutes` les montre aussi. Le texte filtre par nom ou code, sans tenir compte des accents ni de la casse.
 */
export function enseignesVisibles(
  centrales: readonly CentraleAdmin[],
  comptes: ReadonlyMap<string, number>,
  texte: string,
  toutes: boolean,
): { visibles: CentraleAdmin[]; masquees: number } {
  const t = sansAccent(texte.trim());
  const correspond = (c: CentraleAdmin) => t === '' || sansAccent(c.nom).includes(t) || sansAccent(c.code).includes(t);
  const utiles = (c: CentraleAdmin) => c.nbClients > 0 || (comptes.get(c.id) ?? 0) > 0;
  const filtrees = centrales.filter(correspond);
  return {
    visibles: toutes ? filtrees : filtrees.filter(utiles),
    masquees: toutes ? 0 : filtrees.filter((c) => !utiles(c)).length,
  };
}

export const pluriel = (n: number, singulier: string, plur = `${singulier}s`): string => `${n} ${n > 1 ? plur : singulier}`;
