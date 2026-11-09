/** Fonctions pures de la carte des équipes (testables sans base). */

/** Plafond de points renvoyés par type (clients / prospects) sur la carte secteur. */
export const CARTE_LIMITE_POINTS = 5000;

/**
 * Code département d'un code postal français : 2 chiffres, `2A` / `2B` pour la Corse
 * (200xx–201xx = Corse-du-Sud, 202xx–209xx = Haute-Corse), 3 chiffres pour les DOM (97x / 98x).
 * Renvoie null si le code postal n'est pas un code français à 5 chiffres (ex. Belgique, 4 chiffres).
 */
export function departementDeCodePostal(codePostal: string | null | undefined): string | null {
  const cp = (codePostal ?? '').trim();
  if (!/^\d{5}$/.test(cp)) return null;
  if (cp.startsWith('97') || cp.startsWith('98')) return cp.slice(0, 3);
  if (cp.startsWith('20')) return Number(cp.slice(0, 3)) <= 201 ? '2A' : '2B';
  const d = cp.slice(0, 2);
  return d === '00' ? null : d;
}

/** Pays considéré comme France : vide, « France » ou « FR » (insensible à la casse). */
export function estFrance(pays: string | null | undefined): boolean {
  const p = (pays ?? '').trim().toUpperCase();
  return p === '' || p === 'FRANCE' || p === 'FR';
}

export interface ComptePostalSecteur {
  codePostal: string | null;
  secteurId: string | null;
  nb: number;
}

/**
 * Région dominante de chaque département : compte les clients par (département, région du secteur)
 * et retient la région la plus représentée (égalité : id de région le plus petit, pour un résultat stable).
 * Ignore les clients sans secteur, sans région ou hors France.
 */
export function departementsParRegion(
  comptes: ComptePostalSecteur[],
  regionParSecteur: Map<string, string | null>,
): { code: string; regionId: string; nbClients: number }[] {
  const parDept = new Map<string, Map<string, number>>();
  for (const c of comptes) {
    const dept = departementDeCodePostal(c.codePostal);
    const regionId = c.secteurId ? regionParSecteur.get(c.secteurId) : null;
    if (!dept || !regionId) continue;
    const m = parDept.get(dept) ?? new Map<string, number>();
    m.set(regionId, (m.get(regionId) ?? 0) + c.nb);
    parDept.set(dept, m);
  }
  const out: { code: string; regionId: string; nbClients: number }[] = [];
  for (const [code, m] of parDept) {
    let best: string | null = null;
    let bestNb = 0;
    for (const [regionId, nb] of m) {
      if (nb > bestNb || (nb === bestNb && best !== null && regionId < best)) {
        best = regionId;
        bestNb = nb;
      }
    }
    if (best) out.push({ code, regionId: best, nbClients: bestNb });
  }
  return out.sort((a, b) => a.code.localeCompare(b.code));
}

/** Clé canonique d'un code représentant : « 068 » et « 68 » comptent ensemble. */
export function canonRepr(code: string): string {
  const c = code.trim();
  return /^\d+$/.test(c) ? String(Number(c)) : c;
}
