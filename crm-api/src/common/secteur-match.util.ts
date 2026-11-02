/**
 * Rapprochement d'un libellé AD (attribut `st`) d'un secteur de la liste fournie, en tolérant les fautes de frappe.
 * Un libellé trop éloigné ou ambigu renvoie null (jamais deviné). La création éventuelle d'un secteur de référence
 * manquant est faite par `secteur-st.ts`, pas ici.
 */

export interface SecteurRef {
  id: string;
  code: string;
  nom: string;
}

/** Minuscules, sans accents, sans espaces ni ponctuation : « Île-de-France » → « iledefrance ». */
export function normaliserSecteur(label: string): string {
  return label
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

/** Distance d'édition (insertion, suppression, substitution, transposition de deux lettres voisines). */
export function distance(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  const d: number[][] = Array.from({ length: m + 1 }, (_, i) => [i, ...new Array<number>(n).fill(0)]);
  for (let j = 0; j <= n; j++) d[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      const cout = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cout);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[m][n];
}

/** Écart toléré selon la longueur du libellé : aucun sous 5 lettres (trop de faux rapprochements), 1 jusqu'à 8, sinon 2. */
function toleranceFaute(len: number): number {
  if (len < 5) return 0;
  return len <= 8 ? 1 : 2;
}

/**
 * Secteur correspondant au libellé AD : correspondance exacte (nom ou code) d'abord, sinon le secteur le plus
 * proche dans la tolérance. Égalité entre deux secteurs différents → null (ambigu, jamais deviné).
 */
export function trouverSecteur(label: string | null | undefined, secteurs: SecteurRef[]): SecteurRef | null {
  const cible = normaliserSecteur(label ?? '');
  if (!cible) return null;

  const exacts = secteurs.filter((s) => normaliserSecteur(s.nom) === cible || normaliserSecteur(s.code) === cible);
  if (exacts.length === 1) return exacts[0];
  if (exacts.length > 1) return null;

  const tolerance = toleranceFaute(cible.length);
  if (tolerance === 0) return null;

  let meilleur: SecteurRef | null = null;
  let meilleureDistance = Infinity;
  let egalite = false;
  for (const s of secteurs) {
    const dist = Math.min(distance(cible, normaliserSecteur(s.nom)), distance(cible, normaliserSecteur(s.code)));
    if (dist < meilleureDistance) {
      meilleureDistance = dist;
      meilleur = s;
      egalite = false;
    } else if (dist === meilleureDistance && meilleur && meilleur.id !== s.id) {
      egalite = true;
    }
  }
  return meilleur && !egalite && meilleureDistance <= tolerance ? meilleur : null;
}
