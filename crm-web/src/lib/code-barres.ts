/**
 * Choix du symbole à dessiner pour un gencode (module pur). Un code-barres est toujours dessiné quand c'est possible :
 *  1. EAN-13 valide (13 chiffres, clé de contrôle correcte) ;
 *  2. UPC-A valide (12 chiffres) : dessiné comme l'EAN-13 qui commence par 0, ce qui est sa définition ;
 *  3. EAN-8 valide ;
 *  4. sinon Code 128, qui encode exactement la chaîne (autre longueur, clé fausse, lettres…), jamais un faux EAN.
 * Pas de dessin pour une valeur vide, trop longue (Code 128 limité à MAX_CARACTERES_CODE128) ou hors ASCII imprimable.
 */
import { estEan13, modulesEan13 } from './ean13';
import { estEan8, modulesEan8 } from './ean8';
import { modulesCode128 } from './code128';

export type TypeCodeBarres = 'EAN-13' | 'EAN-8' | 'Code 128';

export type SymboleCodeBarres = {
  type: TypeCodeBarres;
  /** Modules du symbole sans zones de silence (« 1 » = barre, « 0 » = espace). */
  modules: string;
  /** Caractères imprimés sous les barres (13 chiffres pour l'EAN-13, 8 pour l'EAN-8, la chaîne pour le Code 128). */
  texte: string;
};

export function symboleCodeBarres(gencode: string | null | undefined): SymboleCodeBarres | null {
  if (typeof gencode !== 'string') return null;
  const code = gencode.trim();
  if (code === '') return null;

  if (estEan13(code)) return { type: 'EAN-13', modules: modulesEan13(code)!, texte: code };
  if (/^\d{12}$/.test(code) && estEan13('0' + code)) {
    return { type: 'EAN-13', modules: modulesEan13('0' + code)!, texte: '0' + code };
  }
  if (estEan8(code)) return { type: 'EAN-8', modules: modulesEan8(code)!, texte: code };

  const modules = modulesCode128(code);
  return modules === null ? null : { type: 'Code 128', modules, texte: code };
}
