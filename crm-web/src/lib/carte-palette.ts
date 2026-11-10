// Palette UNIQUE des régions de la carte des équipes : les teintes de l'annuaire intranet
// (http://intranet.abcosmetique.com/annuaire/), reprises à l'identique pour que la carte soit la même.
//
// Exception documentée à la règle « couleurs = jetons du thème » : ce sont des couleurs CATÉGORIELLES
// (une teinte distincte par région), qu'un thème à deux teintes (bleu / violet) ne peut pas fournir.
// Elles sont posées en JS (`style`) sur les tracés SVG ; les chiffres affichés dessus utilisent le jeton
// `navy-950`. Le nom et l'effectif de chaque région sont toujours écrits en clair : la couleur n'est
// jamais le seul vecteur d'information. Aucun dégradé.

/** Teinte d'une région : bord, point de légende, texte et fonds (normal et appuyé). */
export type TeinteRegion = {
  /** Contour et remplissage de la région survolée ou sélectionnée. */
  bord: string;
  /** Pastille de légende. */
  point: string;
  /** Libellé de la région sur la carte, contour de survol. */
  texte: string;
  /** Fond clair (pastille d'effectif). */
  fond: string;
  /** Remplissage de la région sur la carte. */
  fondFort: string;
};

const TEINTES = {
  orange: { bord: '#fdba74', point: '#f97316', texte: '#c2410c', fond: '#fff7ed', fondFort: '#ffedd5' },
  blue: { bord: '#93c5fd', point: '#60a5fa', texte: '#1d4ed8', fond: '#eff6ff', fondFort: '#dbeafe' },
  violet: { bord: '#c4b5fd', point: '#a78bfa', texte: '#6d28d9', fond: '#f5f3ff', fondFort: '#ede9fe' },
  yellow: { bord: '#fde047', point: '#facc15', texte: '#a16207', fond: '#fefce8', fondFort: '#fef9c3' },
  emerald: { bord: '#6ee7b7', point: '#34d399', texte: '#047857', fond: '#ecfdf5', fondFort: '#d1fae5' },
  cyan: { bord: '#67e8f9', point: '#22d3ee', texte: '#0e7490', fond: '#ecfeff', fondFort: '#cffafe' },
  slate: { bord: '#cbd5e1', point: '#94a3b8', texte: '#475569', fond: '#f8fafc', fondFort: '#f1f5f9' },
} as const satisfies Record<string, TeinteRegion>;

/** Teinte de chaque région, par code de région du CRM (`regions.code`). Même attribution que l'annuaire. */
const TEINTE_PAR_CODE: Record<string, TeinteRegion> = {
  IDF: TEINTES.orange,
  NO: TEINTES.blue,
  NE: TEINTES.violet,
  SE: TEINTES.yellow,
  SO: TEINTES.emerald,
  BENELUX: TEINTES.cyan,
  COR: TEINTES.slate,
};

/** Teinte d'une région d'après son code ; une région inconnue (sans tracé sur la carte) reçoit la teinte neutre. */
export function teinteRegion(code: string): TeinteRegion {
  return TEINTE_PAR_CODE[code] ?? TEINTES.slate;
}
