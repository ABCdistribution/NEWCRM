/** Barre continue d'un code-barres : position (en modules) et largeur (en modules). */
export type Barre = { x: number; largeur: number };

/**
 * Barres d'un symbole décrit module par module (« 1 » = barre, « 0 » = espace) : les modules noirs consécutifs sont
 * fusionnés en une seule barre.
 */
export function barresDeModules(modules: string): Barre[] {
  const barres: Barre[] = [];
  let debut = -1;
  for (let i = 0; i <= modules.length; i++) {
    const noir = i < modules.length && modules[i] === '1';
    if (noir && debut < 0) debut = i;
    if (!noir && debut >= 0) {
      barres.push({ x: debut, largeur: i - debut });
      debut = -1;
    }
  }
  return barres;
}
