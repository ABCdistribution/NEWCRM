/** Spécification d'un champ dans un fichier à largeur fixe. */
export interface FieldSpec {
  name: string;
  start: number; // index de départ (0-based)
  length: number;
}

/** Découpe une ligne à largeur fixe selon la spécification fournie. */
export function parseFixedWidth(line: string, spec: FieldSpec[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const f of spec) {
    out[f.name] = line.substring(f.start, f.start + f.length);
  }
  return out;
}
