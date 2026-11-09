// Fond de carte (départements) : lecture UNIQUE du GeoJSON au premier usage, côté serveur, puis mise en cache.
// Source : gregoiredavid/france-geojson, `departements-version-simplifiee.geojson` (licence ouverte Etalab).
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { projeter, type FondDepartement } from './carte-geo';

type Anneau = number[][];
type Geometrie =
  | { type: 'Polygon'; coordinates: Anneau[] }
  | { type: 'MultiPolygon'; coordinates: Anneau[][] };
type GeoJson = { features: { properties: { code: string }; geometry: Geometrie }[] };

let cache: FondDepartement[] | null = null;
let erreurCache: string | null = null;

/** Projette un anneau, supprime les points trop proches (< 0,4 unité) ; renvoie tracé, aire signée et centroïde. */
function traiterAnneau(anneau: Anneau) {
  const pts: [number, number][] = [];
  for (const [lon, lat] of anneau) {
    const p = projeter(lon, lat);
    const dernier = pts[pts.length - 1];
    if (!dernier || Math.hypot(p[0] - dernier[0], p[1] - dernier[1]) >= 0.4) pts.push(p);
  }
  let aire = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < pts.length; i++) {
    const [x0, y0] = pts[i];
    const [x1, y1] = pts[(i + 1) % pts.length];
    const c = x0 * y1 - x1 * y0;
    aire += c;
    cx += (x0 + x1) * c;
    cy += (y0 + y1) * c;
  }
  aire /= 2;
  const d =
    pts.length >= 3 ? `M${pts.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join('L')}Z` : '';
  return { d, aire, cx: aire ? cx / (6 * aire) : 0, cy: aire ? cy / (6 * aire) : 0 };
}

function construire(): FondDepartement[] {
  const brut = readFileSync(path.join(process.cwd(), 'public', 'geo', 'departements.geojson'), 'utf8');
  const geo = JSON.parse(brut) as GeoJson;
  return geo.features.map((f) => {
    const polygones = f.geometry.type === 'Polygon' ? [f.geometry.coordinates] : f.geometry.coordinates;
    let d = '';
    let aireTot = 0;
    let sx = 0;
    let sy = 0;
    for (const poly of polygones) {
      // Le tracé inclut les trous (fill-rule evenodd) ; le centroïde ne retient que les anneaux extérieurs.
      poly.forEach((anneau, i) => {
        const r = traiterAnneau(anneau);
        d += r.d;
        if (i === 0) {
          const a = Math.abs(r.aire);
          aireTot += a;
          sx += r.cx * a;
          sy += r.cy * a;
        }
      });
    }
    return {
      code: String(f.properties.code),
      d,
      cx: aireTot ? sx / aireTot : 0,
      cy: aireTot ? sy / aireTot : 0,
      aire: aireTot,
    };
  });
}

/** Départements projetés, ou une erreur (message français) si le fichier est illisible. */
export function fondDepartements(): { deps: FondDepartement[] | null; erreur: string | null } {
  if (!cache && !erreurCache) {
    try {
      cache = construire();
    } catch {
      erreurCache = 'Fond de carte indisponible (fichier des départements illisible).';
    }
  }
  return { deps: cache, erreur: erreurCache };
}
