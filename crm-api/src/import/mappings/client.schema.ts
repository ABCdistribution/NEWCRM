import { z } from 'zod';

/**
 * Schéma de validation d'une ligne client Minos.
 * IMPORTANT : ne contient QUE des champs Minos (volatils). Les champs CRM
 * (actif, niveauClass, secteur, commerciaux résolus, notes…) sont volontairement
 * absents : ils ne doivent jamais être touchés par l'import.
 */
export const clientRowSchema = z.object({
  codeAs400: z.string().trim().min(1, 'codeAs400 manquant'),
  enseigne: z.string().trim().default(''),
  raisonSociale: z.string().trim().default(''),
  adresse1: z.string().trim().optional(),
  adresse2: z.string().trim().optional(),
  adresse3: z.string().trim().optional(),
  codePostal: z.string().trim().optional(),
  codePostal2: z.string().trim().optional(),
  ville: z.string().trim().optional(),
  langue: z.string().trim().optional(),
  pays: z.string().trim().optional(),
  devise: z.string().trim().optional(),
  siret: z.string().trim().optional(),
  formeEntreprise: z.string().trim().optional(),
  contact1: z.string().trim().optional(),
  contact2: z.string().trim().optional(),
  contact3: z.string().trim().optional(),
  tel1: z.string().trim().optional(),
  tel2: z.string().trim().optional(),
  idCommercial1: z.string().trim().optional(),
  idCommercial2: z.string().trim().optional(),
  statutCommande: z.string().trim().optional(),
  statutLivre: z.string().trim().optional(),
  statutFacture: z.string().trim().optional(),
  eanClient: z.string().trim().optional(),
});

export type ClientRow = z.infer<typeof clientRowSchema>;

const clean = (v?: string): string | null => {
  if (!v) return null;
  const t = v.trim();
  // Valeurs "vides" propres à Minos (masquées / non renseignées).
  if (t === '' || /^\*+$/.test(t) || /^0+$/.test(t)) return null;
  return t;
};

/** Transforme une ligne validée en payload d'upsert (champs Minos uniquement). */
export function toMinosClientData(row: ClientRow) {
  return {
    codeAs400: row.codeAs400,
    enseigne: row.enseigne,
    raisonSociale: row.raisonSociale,
    adresse1: clean(row.adresse1),
    adresse2: clean(row.adresse2),
    adresse3: clean(row.adresse3),
    codePostal: clean(row.codePostal),
    codePostal2: clean(row.codePostal2),
    ville: clean(row.ville),
    langue: clean(row.langue),
    pays: clean(row.pays),
    devise: clean(row.devise),
    siret: clean(row.siret),
    formeEntreprise: clean(row.formeEntreprise),
    contact1: clean(row.contact1),
    contact2: clean(row.contact2),
    contact3: clean(row.contact3),
    tel1: clean(row.tel1),
    tel2: clean(row.tel2),
    idCommercial1: clean(row.idCommercial1),
    idCommercial2: clean(row.idCommercial2),
    statutCommande: clean(row.statutCommande),
    statutLivre: clean(row.statutLivre),
    statutFacture: clean(row.statutFacture),
    eanClient: clean(row.eanClient),
  };
}
