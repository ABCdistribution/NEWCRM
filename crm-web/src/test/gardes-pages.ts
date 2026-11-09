/**
 * Utilitaire de TESTS (jamais importé par l'application) : lit, dans le code source d'une page ou d'un
 * layout, la liste de rôles passée à `await requireRole(...)`.
 *
 * Pourquoi une analyse du texte ? La table ROUTES (src/lib/routes.ts) dit « la page applique la même règle
 * via requireRole » : rien ne l'impose à l'exécution. Ce lecteur permet de vérifier la cohérence sans
 * rendre les pages (donc sans session ni API).
 *
 * Expressions comprises (ce sont les seules utilisées dans crm-web) :
 *  - un identifiant connu (TOUS_ROLES, ENCADREMENT, TERRAIN : fournis par l'appelant) ;
 *  - une constante locale du fichier : `const ALLOWED = ['ADMIN', ...] as const;` ou
 *    `const ROLES: readonly Role[] = ['COMMERCIAL', ...ENCADREMENT];` ;
 *  - un tableau littéral, avec des chaînes et des `...IDENTIFIANT`.
 * Toute autre forme provoque une ERREUR explicite (jamais un résultat approximatif) : adapter alors ce
 * lecteur ou la page.
 */
import { readFileSync } from 'node:fs';
import { RACINE_APP } from './pages-reelles';

export type Garde = { roles: string[] } | { erreur: string };

export type RolesConnus = Record<string, readonly string[]>;

const APPEL = 'await requireRole(';

/** Code source d'un fichier de src/app (chemin relatif à src/app, séparateur « / »). */
export function lireFichierApp(fichier: string): string {
  return readFileSync([RACINE_APP, fichier].join('/'), 'utf8');
}

/** Texte entre les parenthèses du premier `await requireRole(...)`, ou null s'il n'y en a pas. */
export function extraireArgument(code: string): string | null {
  const debut = code.indexOf(APPEL);
  if (debut < 0) return null;
  const premier = debut + APPEL.length;
  let profondeur = 1;
  for (let i = premier; i < code.length; i++) {
    const c = code[i];
    if (c === '(' || c === '[' || c === '{') profondeur++;
    else if (c === ')' || c === ']' || c === '}') {
      profondeur--;
      if (profondeur === 0) return code.slice(premier, i);
    }
  }
  throw new Error('parenthèse fermante introuvable après « await requireRole( »');
}

function evaluerTableau(texte: string, code: string, connus: RolesConnus, profondeur: number): string[] {
  const elements = texte
    .slice(1, -1)
    .split(',')
    .map((e) => e.trim())
    .filter((e) => e !== '');
  const roles: string[] = [];
  for (const element of elements) {
    const chaine = /^(['"])([A-Z_]+)\1$/.exec(element);
    if (chaine) roles.push(chaine[2]);
    else if (element.startsWith('...')) roles.push(...evaluer(element.slice(3), code, connus, profondeur + 1));
    else throw new Error(`élément de tableau non géré : « ${element} »`);
  }
  return roles;
}

function evaluer(expression: string, code: string, connus: RolesConnus, profondeur = 0): string[] {
  if (profondeur > 5) throw new Error('constantes imbriquées trop profondément');
  // « as const », « as readonly Role[] » : sans effet sur la valeur.
  const texte = expression.replace(/\s+as\s+[\s\S]+$/, '').trim();
  if (texte.startsWith('[') && texte.endsWith(']')) return evaluerTableau(texte, code, connus, profondeur);
  if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(texte)) {
    if (Object.hasOwn(connus, texte)) return [...connus[texte]];
    const locale = new RegExp(`const\\s+${texte}\\b(?:\\s*:\\s*[^=]+?)?\\s*=\\s*(\\[[^\\]]*\\])`).exec(code);
    if (locale) return evaluerTableau(locale[1], code, connus, profondeur + 1);
    throw new Error(`identifiant « ${texte} » inconnu (ni rôle connu, ni constante tableau du fichier)`);
  }
  throw new Error(`expression non gérée : « ${texte} »`);
}

/** Rôles autorisés par le premier `await requireRole(...)` du code (triés, sans doublon). */
export function lireGarde(code: string, connus: RolesConnus): Garde {
  try {
    const argument = extraireArgument(code);
    if (argument === null) return { erreur: 'aucun appel « await requireRole(… » dans ce fichier' };
    return { roles: [...new Set(evaluer(argument, code, connus))].sort() };
  } catch (e) {
    return { erreur: e instanceof Error ? e.message : String(e) };
  }
}
