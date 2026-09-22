import { z } from 'zod';

/** Ligne du fichier centrales : rattachement d'un client à sa hiérarchie d'achat. */
export const centraleRowSchema = z.object({
  codeClient: z.string().trim().min(1, 'codeClient manquant'),
  codeSsCentrale: z.string().trim().optional(),
  nomSsCentrale: z.string().trim().optional(),
  codeSCentrale: z.string().trim().optional(),
  nomSCentrale: z.string().trim().optional(),
  codeCentrale: z.string().trim().optional(),
  nomCentrale: z.string().trim().optional(),
});

export type CentraleRow = z.infer<typeof centraleRowSchema>;
