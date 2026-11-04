// Palette UNIQUE des régions de la carte : teintes pastel unies (pas de dégradé).
// Attribuée selon l'ordre des régions ; au-delà de 12, on boucle.
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
