/**
 * Jeux de données de TESTS (jamais importés par l'application) : fiches produit au format de GET /articles/:id.
 * Valeurs fictives, sauf la fiche « AC-FIL POLY 200M ROSE » reprise de la demande.
 */
import type { ArticleDetail } from '@/lib/api';

/** Fiche de la demande : fil à coudre « AC-FIL POLY 200M ROSE » (sans promotion ni règle de remplacement). */
export const FIL: ArticleDetail = {
  id: '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50',
  codeAs400: '20738',
  libelle: 'AC-FIL POLY 200M ROSE',
  gencode: '3666085207382',
  idIta: null,
  typeArticle: 'Textile',
  statut: 'TEXT',
  sousStatut: 'ACTIF',
  retourAutorise: false,
  actif: true,
  codeTva: '001',
  pcb: 12,
  stock: 48,
  famillePlan: 'ATELIER C&C',
  familleAcd: 'FIL MERCERIE',
  sousFamilleAcd: null,
  sousFamille: null,
  details: null,
  avantages: null,
  marque: { nom: 'ATELIER C&C' },
  gamme: { nom: 'MERCERIE' },
  famille: { nom: 'TEXTILE' },
  tarifs: [{ codeTarif: '80', montant: 3.5 }],
  prixIndicatif: 3.5,
  enPromo: false,
  promoLibelle: null,
  misEnAvant: false,
  substitutionId: null,
  promos: [],
  remplacements: [],
};

/** Identifiant du produit remplaçant de `RICHE`. */
export const ID_REMPLACANT = '8a1d6c20-1b3e-4f7a-8c9d-2e4f6a8b0c1d';

/** Fiche complète : plusieurs tarifs, promotion, mise en avant, retour autorisé, stock faible, une règle de remplacement. */
export const RICHE: ArticleDetail = {
  ...FIL,
  id: '9b2c1f0e-5a47-4c8e-8d3a-0f6e2b7a1c55',
  codeAs400: '900030',
  libelle: 'GEL DOUCHE <EXTRA> 250ML',
  retourAutorise: true,
  stock: 6,
  pcb: 12,
  details: 'Première ligne\nSeconde ligne',
  avantages: 'Sans parfum',
  tarifs: [
    { codeTarif: '10', montant: 4.9 },
    { codeTarif: '80', montant: 1234.5 },
  ],
  prixIndicatif: 4.9,
  enPromo: true,
  promoLibelle: 'Opération de novembre',
  misEnAvant: true,
  substitutionId: ID_REMPLACANT,
  promos: [{ libelle: 'Opération de novembre', dateDebut: '2026-11-01T00:00:00.000Z', dateFin: '2026-11-30T00:00:00.000Z' }],
  remplacements: [
    {
      seuil: 10,
      article: {
        id: ID_REMPLACANT,
        codeAs400: '900015',
        libelle: 'GEL DOUCHE ECO 500ML',
        gencode: null,
        stock: 323,
        actif: true,
        marque: { nom: 'ABC Cosmétique' },
      },
    },
  ],
};
