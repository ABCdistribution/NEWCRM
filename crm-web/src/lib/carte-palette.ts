// Palette UNIQUE des régions de la carte : teintes pastel unies (pas de dégradé).
// Attribuée selon l'ordre des régions ; au-delà de 12, on boucle.
//
// Exception documentée à la règle « couleurs = jetons du thème » : ce sont des couleurs CATÉGORIELLES
// (une teinte distincte par région, jusqu'à 12 régions), qu'un thème à deux teintes (bleu / violet)
// ne peut pas fournir. Elles sont posées en JS (`style`) sur les tracés SVG ; les chiffres affichés
// dessus utilisent le jeton `navy-950` (texte sombre, lisible sur ces pastels). Le nom et l'effectif
// de chaque région sont toujours écrits en clair : la couleur n'est jamais le seul vecteur d'information.
export const PALETTE_REGIONS = [
  '#f6b8c4', // rose
  '#b9d8f5', // bleu ciel
  '#f7d9a0', // sable
  '#bfe5c3', // menthe
  '#d6c4f2', // lilas
  '#f8c9a8', // pêche
  '#a9e0dc', // turquoise
  '#e9e19a', // citron
  '#e3b9d9', // mauve
  '#c3d1f0', // pervenche
  '#f2c4b5', // corail
  '#cfe6a8', // pistache
] as const;

export function couleurRegion(index: number): string {
  return PALETTE_REGIONS[((index % PALETTE_REGIONS.length) + PALETTE_REGIONS.length) % PALETTE_REGIONS.length];
}
