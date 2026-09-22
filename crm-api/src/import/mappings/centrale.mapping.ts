import { FieldSpec } from '../fixed-width-parser';

/**
 * Layout du fichier centrales Minos (`ARB_*.txt`), d'après `struc_ref_centrale`
 * (largeur fixe, 130 caractères). `start` = index 0-based.
 * Chaque ligne rattache un client à sa hiérarchie d'achat sur 3 niveaux :
 * centrale (haut) → sous-centrale → sous-sous-centrale (feuille où pointe le client).
 * La société (CSTE, 1-4) est ignorée.
 */
export const centraleFieldSpec: FieldSpec[] = [
  { name: 'codeClient', start: 4, length: 9 }, // CLIC (5-13)
  { name: 'codeSsCentrale', start: 13, length: 9 }, // CENT01 (14-22)
  { name: 'nomSsCentrale', start: 22, length: 30 }, // RSCT01 (23-52)
  { name: 'codeSCentrale', start: 52, length: 9 }, // CENT02 (53-61)
  { name: 'nomSCentrale', start: 61, length: 30 }, // RSCT02 (62-91)
  { name: 'codeCentrale', start: 91, length: 9 }, // CENT03 (92-100)
  { name: 'nomCentrale', start: 100, length: 30 }, // RSCT03 (101-130)
];
