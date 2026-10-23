/**
 * Fichiers d'interface Minos (AS400) : le préfixe du nom indique le type d'import.
 * Même règle que l'API (`ImportService`), qui refuse un fichier dont le préfixe ne correspond pas.
 */
export const TYPES_MINOS = {
  CLI: { label: 'Clients', route: 'clients', ordre: 1 },
  ART: { label: 'Articles', route: 'articles', ordre: 2 },
  ARB: { label: "Arborescence d'achat", route: 'centrales', ordre: 3 },
} as const;

export type TypeMinos = keyof typeof TYPES_MINOS;

/** Type d'un fichier d'après son préfixe (CLI_, ART_, ARB_), ou null s'il n'est pas reconnu. */
export function typeMinos(nom: string): TypeMinos | null {
  const prefixe = nom.toUpperCase().slice(0, 3);
  return prefixe in TYPES_MINOS ? (prefixe as TypeMinos) : null;
}

/** 1 536 → « 1,5 Ko ». */
export function formatTaille(octets: number | null | undefined): string {
  if (octets == null) return '—';
  if (octets < 1024) return `${octets} o`;
  if (octets < 1024 * 1024) return `${(octets / 1024).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} Ko`;
  return `${(octets / (1024 * 1024)).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} Mo`;
}

/** 83 s → « 1 min 23 s ». */
export function formatDuree(secondes: number | null): string {
  if (secondes == null) return '—';
  if (secondes < 60) return `${secondes} s`;
  return `${Math.floor(secondes / 60)} min ${String(secondes % 60).padStart(2, '0')} s`;
}
