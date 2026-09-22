import { FieldSpec } from '../fixed-width-parser';

/**
 * Layout du fichier articles Minos (`ART_*.txt`), d'après la table de découpe
 * officielle `struc_ref_article` (enregistrement = 152 caractères, largeur fixe).
 * `start` = index 0-based.
 *
 * Champs volontairement ignorés (morts / non stockés) :
 *  - zparm_nb_uc (109-115), zparm_x_pcb (116-122), zparm_spcb (123-129) : colonnes mortes
 *  - date fin de vie vente (130-137) : parsée mais non stockée dans le legacy
 */
export const articleFieldSpec: FieldSpec[] = [
  { name: 'codeAs400', start: 0, length: 15 }, // CDART (1-15)
  { name: 'libelle', start: 15, length: 30 }, // LIBART (16-45)
  { name: 'codeFamille', start: 45, length: 5 }, // FAMILL (46-50)
  { name: 'sousFamille', start: 50, length: 5 }, // SFAMIL (51-55)
  { name: 'typeArticle', start: 55, length: 1 }, // TYPART (56)
  { name: 'codeMarque', start: 56, length: 5 }, // CDMARQ (57-61)
  { name: 'codeTva', start: 61, length: 1 }, // TAXTVA (62)
  { name: 'gamme', start: 62, length: 5 }, // FAMSTA (63-67)
  { name: 'statut', start: 67, length: 5 }, // ARTSIZ (68-72)
  { name: 'sousStatut', start: 72, length: 5 }, // ARTCOL (73-77)
  { name: 'familleAcd', start: 77, length: 5 }, // FAMACD (78-82)
  { name: 'sousFamilleAcd', start: 82, length: 5 }, // SFAACD (83-87)
  { name: 'famillePlan', start: 87, length: 5 }, // FAMPIC (88-92)
  { name: 'gencode', start: 92, length: 13 }, // EAN (93-105)
  { name: 'pcb', start: 105, length: 3 }, // ZPCB (106-108)
  { name: 'idIta', start: 137, length: 15 }, // ARTLIE (138-152)
];
