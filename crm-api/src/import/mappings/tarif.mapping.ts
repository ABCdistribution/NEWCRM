import { FieldSpec } from '../fixed-width-parser';

/**
 * Layout du fichier tarifs Minos (`TAR_*.txt`), d'après `struc_ref_tarif`
 * (largeur fixe). `start` = index 0-based.
 * Champs ignorés : EAN (16-28), période tarif PERT80 (32-33).
 * Le prix (PRIX80, 34-48) est un entier de 15 chiffres → 4 décimales
 * (valeur brute ÷ 10000, ex. 000000012500000 = 1250.0000).
 */
export const tarifFieldSpec: FieldSpec[] = [
  { name: 'codeArticle', start: 0, length: 15 }, // CDART (1-15) → Article.codeAs400
  { name: 'codeTarif', start: 28, length: 3 }, // CTAR80 (29-31)
  { name: 'prix', start: 33, length: 15 }, // PRIX80 (34-48)
];
