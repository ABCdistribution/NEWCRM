/**
 * Encodage Code 128 (module pur, sans dépendance) : code-barres de repli quand un gencode n'est pas un EAN valide.
 * Le Code 128 encode exactement la chaîne donnée (sa propre clé de contrôle ne modifie jamais le numéro affiché).
 *
 * Jeux utilisés : B (caractères ASCII 32 à 126) et C (paires de chiffres, plus compact). Les chiffres seuls passent
 * en C ; un nombre impair de chiffres (3 ou plus) est en C puis bascule en A pour le dernier chiffre (un chiffre a la
 * même valeur en A et en B, ASCII moins 32).
 */

/** Plus longue chaîne dessinée : au-delà, le symbole serait trop large pour être lisible. */
export const MAX_CARACTERES_CODE128 = 32;

/**
 * Les 107 symboles (valeurs 0 à 106, de 103 à 105 = départs A, B, C ; 106 = arrêt) : largeurs alternées barre / espace,
 * six éléments (11 modules) ; l'arrêt a sept éléments (13 modules).
 */
const MOTIFS = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213',
  '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
  '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
  '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
  '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
  '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
  '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
  '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
  '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
  '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
  '114131', '311141', '411131', '211412', '211214', '211232', '2331112',
] as const;

const DEPART_B = 104;
const DEPART_C = 105;
const ARRET = 106;
const BASCULE_A = 101;

/** Modules (« 1 » = barre, « 0 » = espace) d'un motif de largeurs alternées, en commençant par une barre. */
function modulesDuMotif(motif: string): string {
  let noir = true;
  let modules = '';
  for (const largeur of motif) {
    modules += (noir ? '1' : '0').repeat(Number(largeur));
    noir = !noir;
  }
  return modules;
}

/** Vrai si tous les caractères sont des caractères ASCII imprimables (32 à 126), jeu B. */
function estAsciiImprimable(texte: string): boolean {
  for (let i = 0; i < texte.length; i++) {
    const c = texte.charCodeAt(i);
    if (c < 32 || c > 126) return false;
  }
  return true;
}

/** Valeur d'un caractère du jeu B. */
const valeurB = (caractere: string): number => caractere.charCodeAt(0) - 32;

/**
 * Valeurs des symboles de données (départ compris, clé de contrôle et arrêt exclus), ou null si la chaîne est vide,
 * trop longue ou contient un caractère hors ASCII imprimable.
 */
export function valeursCode128(texte: string | null | undefined): number[] | null {
  if (typeof texte !== 'string' || texte.length === 0 || texte.length > MAX_CARACTERES_CODE128) return null;
  if (!estAsciiImprimable(texte)) return null;

  if (/^\d+$/.test(texte)) {
    const paires = (chiffres: string): number[] => {
      const valeurs: number[] = [];
      for (let i = 0; i < chiffres.length; i += 2) valeurs.push(Number(chiffres.slice(i, i + 2)));
      return valeurs;
    };
    if (texte.length % 2 === 0) return [DEPART_C, ...paires(texte)];
    if (texte.length === 1) return [DEPART_B, valeurB(texte)];
    // Nombre impair de chiffres : paires en C, puis bascule en A pour le dernier chiffre (même valeur en A et en B).
    return [DEPART_C, ...paires(texte.slice(0, -1)), BASCULE_A, valeurB(texte[texte.length - 1])];
  }
  return [DEPART_B, ...Array.from(texte, valeurB)];
}

/** Clé de contrôle : (départ + somme de position × valeur) modulo 103. */
export function cleCode128(valeurs: readonly number[]): number {
  let somme = valeurs[0];
  for (let i = 1; i < valeurs.length; i++) somme += i * valeurs[i];
  return somme % 103;
}

/**
 * Modules du symbole complet (sans zones de silence) : données, clé de contrôle et arrêt ; null si la chaîne ne peut
 * pas être encodée (vide, plus de MAX_CARACTERES_CODE128 caractères, caractère hors ASCII imprimable).
 */
export function modulesCode128(texte: string | null | undefined): string | null {
  const valeurs = valeursCode128(texte);
  if (valeurs === null) return null;
  const symboles = [...valeurs, cleCode128(valeurs), ARRET];
  return symboles.map((v) => modulesDuMotif(MOTIFS[v])).join('');
}

/** Table des motifs, exposée pour les tests de structure. */
export const MOTIFS_CODE128: readonly string[] = MOTIFS;
