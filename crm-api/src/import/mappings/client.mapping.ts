import { FieldSpec } from '../fixed-width-parser';

/**
 * Layout du fichier clients Minos (`CLI_*.txt`), d'après la table de découpe
 * officielle `struc_ref_client` (largeur fixe). `start` = index 0-based.
 *
 * Positions parsées mais NON stockées (ignorées) :
 *  - CSTE société (1-4), CNUD (232-237), CIF (238-242), code_region (391-395)
 * Le code client (id_as400) est cols 5-13 → préfixe société « ABC » retiré.
 */
export const clientFieldSpec: FieldSpec[] = [
  { name: 'codeAs400', start: 4, length: 9 }, // CLI (5-13)
  { name: 'enseigne', start: 13, length: 30 }, // ENSEIG (14-43)
  { name: 'raisonSociale', start: 43, length: 30 }, // RSCLT (44-73)
  { name: 'adresse1', start: 73, length: 30 }, // ADR1 (74-103)
  { name: 'adresse2', start: 103, length: 30 }, // ADR2 (104-133)
  { name: 'adresse3', start: 133, length: 30 }, // ADR3 (134-163)
  { name: 'codePostal', start: 163, length: 5 }, // CPOST (164-168)
  { name: 'codePostal2', start: 168, length: 5 }, // CPOSTC (169-173)
  { name: 'ville', start: 173, length: 35 }, // VILLE (174-208)
  { name: 'langue', start: 208, length: 3 }, // CLANGC (209-211)
  { name: 'pays', start: 211, length: 3 }, // CPAYS (212-214)
  { name: 'devise', start: 214, length: 3 }, // CDEVC (215-217)
  { name: 'siret', start: 217, length: 14 }, // SIRET (218-231)
  { name: 'formeEntreprise', start: 242, length: 4 }, // FRMENT (243-246)
  { name: 'contact1', start: 246, length: 30 }, // CORCCE (247-276)
  { name: 'contact2', start: 276, length: 30 }, // CORADM (277-306)
  { name: 'contact3', start: 306, length: 30 }, // CORTEC (307-336)
  { name: 'tel1', start: 336, length: 14 }, // TELEPH (337-350)
  { name: 'tel2', start: 350, length: 14 }, // TELECO (351-364)
  { name: 'idCommercial1', start: 364, length: 5 }, // REPR1 (365-369)
  { name: 'idCommercial2', start: 369, length: 5 }, // REPR2 (370-374)
  { name: 'statutCommande', start: 374, length: 1 }, // STSCOM (375)
  { name: 'statutLivre', start: 375, length: 1 }, // STSLIV (376)
  { name: 'statutFacture', start: 376, length: 1 }, // STSFAC (377)
  { name: 'eanClient', start: 377, length: 13 }, // EAN (378-390)
];
