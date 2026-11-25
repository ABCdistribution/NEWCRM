/**
 * Encodage EAN-8 (module pur, sans dépendance) : symbole de 67 modules = garde (101), quatre chiffres de gauche (jeu L),
 * garde centrale (01010), quatre chiffres de droite (jeu R), garde (101).
 */
import { JEU_L, JEU_R } from './ean13';

/** Nombre de modules du symbole (sans les zones de silence). */
export const MODULES_EAN8 = 67;

/** Positions (en modules) des gardes, qui descendent plus bas que les autres barres. */
export const GARDES_EAN8: readonly { x: number; largeur: number }[] = [
  { x: 0, largeur: 3 },
  { x: 31, largeur: 5 },
  { x: 64, largeur: 3 },
];

/** Clé de contrôle (8e chiffre) des sept premiers chiffres (poids 3, 1, 3, 1…) ; null si ce ne sont pas sept chiffres. */
export function cleEan8(sept: string): number | null {
  if (!/^\d{7}$/.test(sept)) return null;
  let somme = 0;
  for (let i = 0; i < 7; i++) somme += Number(sept[i]) * (i % 2 === 0 ? 3 : 1);
  return (10 - (somme % 10)) % 10;
}

/** Vrai pour exactement 8 chiffres dont la clé de contrôle est correcte. */
export function estEan8(code: string | null | undefined): code is string {
  if (typeof code !== 'string' || !/^\d{8}$/.test(code)) return false;
  return cleEan8(code.slice(0, 7)) === Number(code[7]);
}

/** Les 67 modules du symbole, ou null si le code n'est pas un EAN-8 valide. */
export function modulesEan8(code: string | null | undefined): string | null {
  if (!estEan8(code)) return null;
  let gauche = '';
  let droite = '';
  for (let i = 0; i < 4; i++) gauche += JEU_L[Number(code[i])];
  for (let i = 4; i < 8; i++) droite += JEU_R[Number(code[i])];
  return '101' + gauche + '01010' + droite + '101';
}
