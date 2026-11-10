// Géométrie de la carte de France : fonctions pures (utilisables côté serveur ET client).
// Projection équirectangulaire corrigée par cos(latitude moyenne) : adaptée à la métropole
// (lon -5,5…10 ; lat 41…51,5), Corse comprise, à sa place réelle.

export const LON_MIN = -5.5;
export const LAT_MAX = 51.5;
const COS_LAT = Math.cos((46.25 * Math.PI) / 180);
/** Unités SVG par degré de latitude. */
const ECHELLE = 60;

export const VIEWBOX_W = Math.round((10 + 5.5) * COS_LAT * ECHELLE); // ≈ 643
export const VIEWBOX_H = Math.round((51.5 - 41) * ECHELLE); // 630

/** lon/lat (degrés) → [x, y] dans le viewBox SVG. */
export function projeter(lon: number, lat: number): [number, number] {
  return [(lon - LON_MIN) * COS_LAT * ECHELLE, (LAT_MAX - lat) * ECHELLE];
}

/** Département du fond de carte, déjà projeté. */
export type FondDepartement = {
  code: string;
  /** Tracé SVG (attribut `d`). */
  d: string;
  /** Centroïde projeté. */
  cx: number;
  cy: number;
  /** Aire projetée (pondération des centroïdes de région). */
  aire: number;
};

/** Centroïde de région : moyenne des centroïdes de ses départements pondérée par leur aire. */
export function centroideRegion(deps: FondDepartement[]): { x: number; y: number } | null {
  let a = 0;
  let x = 0;
  let y = 0;
  for (const d of deps) {
    a += d.aire;
    x += d.cx * d.aire;
    y += d.cy * d.aire;
  }
  return a > 0 ? { x: x / a, y: y / a } : null;
}
