/**
 * Encodage EAN-13 (module pur, sans dépendance) : sert à dessiner le code-barres d'un produit en SVG.
 *
 * Symbole de 95 modules : garde de début (101), six chiffres de gauche (42 modules, jeux L ou G selon le premier chiffre),
 * garde centrale (01010), six chiffres de droite (42 modules, jeu R), garde de fin (101). Le premier chiffre n'est pas
 * dessiné : il est porté par la combinaison des jeux L / G de la partie gauche.
 */

import { barresDeModules, type Barre } from './barres';

/** Nombre de modules du symbole (sans les zones de silence). */
export const MODULES_EAN13 = 95;

const GARDE = '101';
const CENTRE = '01010';

/** Jeu L (parité impaire), chiffres 0 à 9 (partagé avec l'EAN-8). */
export const JEU_L = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
/** Jeu G (parité paire) = jeu R inversé, chiffres 0 à 9. */
const G = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
/** Jeu R (côté droit) = complément du jeu L, chiffres 0 à 9 (partagé avec l'EAN-8). */
export const JEU_R = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
const L = JEU_L;
const R = JEU_R;

/** Jeux des six chiffres de gauche selon le premier chiffre du code. */
const PARITE = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];

/** Clé de contrôle (13e chiffre) des douze premiers chiffres ; null si ce ne sont pas douze chiffres. */
export function cleEan13(douze: string): number | null {
  if (!/^\d{12}$/.test(douze)) return null;
  let somme = 0;
  for (let i = 0; i < 12; i++) somme += Number(douze[i]) * (i % 2 === 0 ? 1 : 3);
  return (10 - (somme % 10)) % 10;
}

/** Vrai pour exactement 13 chiffres dont la clé de contrôle est correcte (espaces et tirets NON tolérés). */
export function estEan13(code: string | null | undefined): code is string {
  if (typeof code !== 'string' || !/^\d{13}$/.test(code)) return false;
  return cleEan13(code.slice(0, 12)) === Number(code[12]);
}

/** Les 95 modules du symbole (« 1 » = barre, « 0 » = espace), ou null si le code n'est pas un EAN-13 valide. */
export function modulesEan13(code: string | null | undefined): string | null {
  if (!estEan13(code)) return null;
  const parite = PARITE[Number(code[0])];
  let gauche = '';
  for (let i = 0; i < 6; i++) {
    const chiffre = Number(code[i + 1]);
    gauche += parite[i] === 'L' ? L[chiffre] : G[chiffre];
  }
  let droite = '';
  for (let i = 7; i < 13; i++) droite += R[Number(code[i])];
  return GARDE + gauche + CENTRE + droite + GARDE;
}

export type { Barre };

/** Barres du symbole (modules noirs consécutifs fusionnés), ou null si le code n'est pas un EAN-13 valide. */
export function barresEan13(code: string | null | undefined): Barre[] | null {
  const modules = modulesEan13(code);
  return modules === null ? null : barresDeModules(modules);
}

/** Positions (en modules, depuis le début du symbole) des gardes, qui descendent plus bas que les autres barres. */
export const GARDES_EAN13: readonly { x: number; largeur: number }[] = [
  { x: 0, largeur: 3 },
  { x: 45, largeur: 5 },
  { x: 92, largeur: 3 },
];
