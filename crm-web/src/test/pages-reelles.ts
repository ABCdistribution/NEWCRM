/**
 * Utilitaire de TESTS (jamais importé par l'application) : inventaire des pages et des route handlers
 * réels de crm-web, lu sur le disque sous src/app.
 *
 * Règles de routage de Next 15 reprises ici (ce sont les seules utilisées par crm-web) :
 *  - un dossier « (groupe) » n'apparaît pas dans l'URL ;
 *  - un dossier « [id] » est un segment dynamique (un seul segment) ;
 *  - seuls `page.*` (page) et `route.*` (route handler) définissent une URL ; layout, template, loading
 *    et composants voisins n'en définissent pas.
 *
 *  - un dossier privé « _x » est ignoré (il ne définit aucune URL).
 *
 * Conventions que crm-web n'utilise pas (@slot, (.)intercepté, [...catch-all]) : l'utilitaire REFUSE de
 * les interpréter au lieu de calculer une URL fausse. Si l'une d'elles apparaît, les tests qui s'appuient
 * sur cet inventaire échouent avec un message explicite : il faut alors compléter l'utilitaire
 * (et non contourner le test).
 */
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/** Dossier src/app (chemin absolu, séparateurs de la plateforme). */
export const RACINE_APP = fileURLToPath(new URL('../app', import.meta.url));

export type FichierRoute = {
  /** URL avec segments dynamiques, groupes de routes retirés (« /clients/[id]/visite »). « / » pour l'accueil. */
  url: string;
  type: 'page' | 'route';
  /** Chemin relatif à src/app, séparateur « / » (« (app)/clients/[id]/page.tsx »). */
  fichier: string;
  /** Groupes de routes traversés, du plus externe au plus interne (« ['app', 'direction'] »). */
  groupes: string[];
};

/** Deux valeurs d'exemple pour les segments dynamiques (UUID de fantaisie, jamais de vraie donnée). */
export const ID_EXEMPLE = '123e4567-e89b-42d3-a456-426614174000';
export const ID_EXEMPLE_2 = '9b2c1f0e-5a47-4c8e-8d3a-0f6e2b7a1c55';

const FICHIER_URL = /^(page|route)\.(?:tsx|ts|jsx|js)$/;
const GROUPE = /^\(([^).][^)]*)\)$/;
const SEGMENT_DYNAMIQUE = /^\[([A-Za-z_][A-Za-z0-9_]*)\]$/;

function comparer(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

function verifierDossier(nom: string, chemin: string): void {
  const nonGere =
    nom.startsWith('@') || // route parallèle
    /^\(\.+\)/.test(nom) || // route interceptée
    /^\[\.{3}|^\[\[/.test(nom); // catch-all
  if (nonGere) {
    throw new Error(
      `pages-reelles : le dossier « ${chemin} » utilise une convention de routage que l'utilitaire ne gère pas : ` +
        `compléter src/test/pages-reelles.ts avant d'ajouter ce dossier.`,
    );
  }
}

function parcourir(segments: string[], sortie: FichierRoute[]): void {
  const dossier = [RACINE_APP, ...segments].join('/');
  const entrees = readdirSync(dossier, { withFileTypes: true }).sort((a, b) => comparer(a.name, b.name));
  for (const entree of entrees) {
    if (entree.isDirectory()) {
      if (entree.name.startsWith('_')) continue; // dossier privé : aucune URL
      verifierDossier(entree.name, [...segments, entree.name].join('/'));
      parcourir([...segments, entree.name], sortie);
      continue;
    }
    const fichier = FICHIER_URL.exec(entree.name);
    if (!fichier) continue;
    const groupes: string[] = [];
    const url: string[] = [];
    for (const segment of segments) {
      const groupe = GROUPE.exec(segment);
      if (groupe) groupes.push(groupe[1]);
      else url.push(segment);
    }
    sortie.push({
      url: `/${url.join('/')}`,
      type: fichier[1] as 'page' | 'route',
      fichier: [...segments, entree.name].join('/'),
      groupes,
    });
  }
}

/** Toutes les pages et tous les route handlers de src/app (lus une seule fois, ordre alphabétique stable). */
export const FICHIERS_ROUTES: readonly FichierRoute[] = (() => {
  const sortie: FichierRoute[] = [];
  parcourir([], sortie);
  return sortie;
})();

/** Les pages seules (page.*), sans les route handlers. */
export const PAGES: readonly FichierRoute[] = FICHIERS_ROUTES.filter((f) => f.type === 'page');

/** Échappe un texte littéral pour l'insérer dans une expression régulière. */
export function echapperRegex(texte: string): string {
  return texte.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function regexDeUrl(url: string): RegExp {
  if (url === '/') return /^\/$/;
  const motif = url
    .split('/')
    .slice(1)
    .map((segment) => (SEGMENT_DYNAMIQUE.test(segment) ? '[^/]+' : echapperRegex(segment)))
    .join('/');
  return new RegExp(`^/${motif}$`);
}

/** Retire la chaîne de requête, l'ancre et le « / » final (sauf pour la racine). */
export function cheminSeul(chemin: string): string {
  const sansRequete = chemin.split(/[?#]/, 1)[0];
  return sansRequete.length > 1 ? sansRequete.replace(/\/+$/, '') : sansRequete;
}

/**
 * Fichier de page (ou de route handler) qui sert une URL CONCRÈTE (« /clients/<uuid>/visite »),
 * ou undefined si Next répondrait 404. La requête et l'ancre sont ignorées.
 */
export function fichierPourUrl(
  chemin: string,
  types: readonly FichierRoute['type'][] = ['page'],
): FichierRoute | undefined {
  const cible = cheminSeul(chemin);
  return FICHIERS_ROUTES.find((f) => types.includes(f.type) && regexDeUrl(f.url).test(cible));
}

/** Remplace les segments dynamiques d'une URL de fichier par des UUID d'exemple (« [id] » -> UUID). */
export function instancier(url: string): string {
  const exemples = [ID_EXEMPLE, ID_EXEMPLE_2];
  let i = 0;
  return url
    .split('/')
    .map((segment) => (SEGMENT_DYNAMIQUE.test(segment) ? exemples[i++ % exemples.length] : segment))
    .join('/');
}
