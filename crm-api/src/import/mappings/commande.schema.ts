import { z } from 'zod';

export const commandeRowSchema = z.object({
  numero: z.string().trim().min(1, 'numero manquant'),
  anneeCmd: z.string().trim().optional(),
  moisCmd: z.string().trim().optional(),
  jourCmd: z.string().trim().optional(),
  codeClient: z.string().trim().optional(),
  raisonSocialeCmd: z.string().trim().optional(),
  idRepr: z.string().trim().optional(),
  codeArticle: z.string().trim().optional(),
  libelleArticle: z.string().trim().optional(),
  quantite: z.string().trim().optional(),
  montant: z.string().trim().optional(),
  typeCmd: z.string().trim().optional(),
  checkAnnee: z.string().trim().optional(),
  checkMois: z.string().trim().optional(),
  checkJour: z.string().trim().optional(),
  noLigne: z.string().trim().optional(),
  idCommandeApk: z.string().trim().optional(),
});

export type CommandeRow = z.infer<typeof commandeRowSchema>;

/** Entier 15 chiffres à 4 décimales implicites → chaîne décimale exacte (ex. "1250.0000"). */
export function parseDecimal4(raw?: string): string {
  if (!raw) return '0';
  const d = raw.replace(/\D/g, '');
  if (!d || /^0+$/.test(d)) return '0';
  const p = d.padStart(5, '0');
  const intPart = p.slice(0, -4).replace(/^0+(?=\d)/, '');
  return `${intPart || '0'}.${p.slice(-4)}`;
}

/** Construit une date depuis AAAA/MM/JJ, ou null si non renseignée / invalide. */
export function parseDate(yyyy?: string, mm?: string, dd?: string): Date | null {
  const y = parseInt((yyyy ?? '').trim(), 10);
  const m = parseInt((mm ?? '').trim(), 10);
  const d = parseInt((dd ?? '').trim(), 10);
  if (!y || y < 1900 || !m || m < 1 || m > 12 || !d || d < 1 || d > 31) return null;
  return new Date(Date.UTC(y, m - 1, d));
}
