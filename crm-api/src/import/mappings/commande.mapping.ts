import { FieldSpec } from '../fixed-width-parser';

/**
 * Layout du fichier commandes Minos (`CDJ_*`), d'après `struc_commandes_as400`
 * (largeur fixe ; l'idCommandeApk final est de longueur variable → lignes de 539
 * sans lien mobile, ~548 avec). `start` = index 0-based.
 * Une ligne = une ligne de commande (un article dans une commande).
 *
 * NB : les positions 11-18 portent la **date de commande** (pas l'annulation) ;
 * la vraie annulation est checky/m/d (527-534), comme dans importAS400.
 *
 * Ignorés : motif modif (10), bloc client livré/facturé (58-135), 3 niveaux de
 * centrale (136-252), cs/dz/dr/repr2 (288-427), dpt, gamme_dang, gamme/marque/
 * famille/famille_acd (476-495, dérivables de l'article).
 */
export const commandeFieldSpec: FieldSpec[] = [
  { name: 'numero', start: 0, length: 9 }, // NUCMDC (1-9)
  { name: 'anneeCmd', start: 10, length: 4 }, // AAANN (11-14) — date commande
  { name: 'moisCmd', start: 14, length: 2 }, // MMANN (15-16)
  { name: 'jourCmd', start: 16, length: 2 }, // JJANN (17-18)
  { name: 'codeClient', start: 18, length: 9 }, // CLIC (19-27)
  { name: 'raisonSocialeCmd', start: 27, length: 30 }, // RSCLTC (28-57)
  { name: 'idRepr', start: 252, length: 5 }, // REPR1 (253-257)
  { name: 'codeArticle', start: 429, length: 15 }, // CDART (430-444)
  { name: 'libelleArticle', start: 444, length: 30 }, // LIBART (445-474)
  { name: 'quantite', start: 495, length: 15 }, // QTFACC (496-510) — 4 décimales
  { name: 'montant', start: 510, length: 15 }, // MNTCMD (511-525) — 4 décimales
  { name: 'typeCmd', start: 525, length: 1 }, // TYPCMD (526)
  { name: 'checkAnnee', start: 526, length: 4 }, // checky (527-530) — annulation
  { name: 'checkMois', start: 530, length: 2 }, // checkm (531-532)
  { name: 'checkJour', start: 532, length: 2 }, // checkd (533-534)
  { name: 'noLigne', start: 534, length: 5 }, // LICMDC (535-539)
  { name: 'idCommandeApk', start: 539, length: 10 }, // IDCRM (540-549)
];
