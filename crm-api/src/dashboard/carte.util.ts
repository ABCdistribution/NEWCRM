/** Fonctions pures de la carte des équipes (testables sans base). */

/** Plafond de points renvoyés par type (clients / prospects) sur la carte secteur. */
export const CARTE_LIMITE_POINTS = 5000;

/** Pays considéré comme France : vide, « France » ou « FR » (insensible à la casse). */
export function estFrance(pays: string | null | undefined): boolean {
  const p = (pays ?? '').trim().toUpperCase();
  return p === '' || p === 'FRANCE' || p === 'FR';
}

/** Clé canonique d'un code représentant : « 068 » et « 68 » comptent ensemble. */
export function canonRepr(code: string): string {
  const c = code.trim();
  return /^\d+$/.test(c) ? String(Number(c)) : c;
}
