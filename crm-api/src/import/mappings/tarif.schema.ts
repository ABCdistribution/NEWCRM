import { z } from 'zod';

export const tarifRowSchema = z.object({
  codeArticle: z.string().trim().min(1, 'codeArticle manquant'),
  codeTarif: z.string().trim().optional(),
  prix: z.string().trim().optional(),
});

export type TarifRow = z.infer<typeof tarifRowSchema>;

/**
 * Convertit le prix brut Minos (15 chiffres, 4 décimales implicites) en
 * chaîne décimale exacte (sans passer par un flottant).
 * Ex. "000000012500000" → "1250.0000". Retourne null si vide / zéro.
 */
export function parsePrix(raw?: string): string | null {
  if (!raw) return null;
  const digits = raw.replace(/\D/g, '');
  if (!digits || /^0+$/.test(digits)) return null;
  const padded = digits.padStart(5, '0'); // au moins 1 chiffre entier + 4 décimales
  const intPart = padded.slice(0, -4).replace(/^0+(?=\d)/, '');
  const decPart = padded.slice(-4);
  return `${intPart || '0'}.${decPart}`;
}
