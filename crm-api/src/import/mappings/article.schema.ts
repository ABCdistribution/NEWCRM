import { z } from 'zod';

/**
 * Schéma de validation d'une ligne article Minos.
 * Les codes de classification (codeMarque, gamme, codeFamille) sont résolus en
 * relations (Marque/Gamme/Famille) par le script d'import, pas ici.
 */
export const articleRowSchema = z.object({
  codeAs400: z.string().trim().min(1, 'codeAs400 manquant'),
  libelle: z.string().trim().default(''),
  codeFamille: z.string().trim().optional(),
  sousFamille: z.string().trim().optional(),
  typeArticle: z.string().trim().optional(),
  codeMarque: z.string().trim().optional(),
  codeTva: z.string().trim().optional(),
  gamme: z.string().trim().optional(),
  statut: z.string().trim().optional(),
  sousStatut: z.string().trim().optional(),
  familleAcd: z.string().trim().optional(),
  sousFamilleAcd: z.string().trim().optional(),
  famillePlan: z.string().trim().optional(),
  gencode: z.string().trim().optional(),
  pcb: z.string().trim().optional(),
  idIta: z.string().trim().optional(),
});

export type ArticleRow = z.infer<typeof articleRowSchema>;

const clean = (v?: string): string | null => {
  if (!v) return null;
  const t = v.trim();
  // Valeurs "vides" Minos : chaîne vide, masquée (***), ou tout à zéro.
  if (t === '' || /^\*+$/.test(t) || /^0+$/.test(t)) return null;
  return t;
};

const toInt = (v?: string): number | null => {
  if (!v) return null;
  const n = parseInt(v.trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : null;
};

/** Champs scalaires Minos de l'article (hors FK marque/gamme/famille). */
export function toMinosArticleData(row: ArticleRow) {
  return {
    codeAs400: row.codeAs400,
    libelle: row.libelle,
    typeArticle: clean(row.typeArticle),
    sousFamille: clean(row.sousFamille),
    codeTva: clean(row.codeTva),
    statut: clean(row.statut),
    sousStatut: clean(row.sousStatut),
    retourAutorise: (row.sousStatut ?? '').trim() === 'RAPPE',
    familleAcd: clean(row.familleAcd),
    sousFamilleAcd: clean(row.sousFamilleAcd),
    famillePlan: clean(row.famillePlan),
    gencode: clean(row.gencode),
    pcb: toInt(row.pcb),
    idIta: clean(row.idIta),
  };
}
