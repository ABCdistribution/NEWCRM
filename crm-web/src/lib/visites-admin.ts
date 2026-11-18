/** Types de question du questionnaire de fin de visite (enum `TypeQuestion` de l'API). */
export const TYPES_QUESTION = ['CASE_A_COCHER', 'TEXTE', 'NOMBRE', 'NOTE_1_5'] as const;
export type TypeQuestion = (typeof TYPES_QUESTION)[number];

export const LIBELLES_TYPE: Record<TypeQuestion, string> = {
  CASE_A_COCHER: 'Case à cocher',
  TEXTE: 'Texte libre',
  NOMBRE: 'Nombre',
  NOTE_1_5: 'Note de 1 à 5',
};

/** Longueurs maximales des libellés (DTO de l'API). */
export const LONGUEUR_QUESTION = 300;
export const LONGUEUR_RAISON = 200;

export type QuestionVisite = {
  id: string;
  libelle: string;
  type: TypeQuestion;
  ordre: number;
  obligatoire: boolean;
  actif: boolean;
  _count: { reponses: number };
};

export type RaisonAbsenceCommande = {
  id: string;
  libelle: string;
  ordre: number;
  actif: boolean;
  _count: { visites: number };
};

export function typeQuestionValide(valeur: string): valeur is TypeQuestion {
  return (TYPES_QUESTION as readonly string[]).includes(valeur);
}

export function directionValide(valeur: string): valeur is 'haut' | 'bas' {
  return valeur === 'haut' || valeur === 'bas';
}

/** Libellé nettoyé, ou message d'erreur s'il est vide ou trop long. */
export function controlerLibelle(
  brut: string,
  max: number,
): { libelle: string; erreur: null } | { libelle: null; erreur: string } {
  const libelle = brut.trim();
  if (!libelle) return { libelle: null, erreur: 'Le libellé est obligatoire.' };
  if (libelle.length > max) return { libelle: null, erreur: `Le libellé est limité à ${max} caractères.` };
  return { libelle, erreur: null };
}
