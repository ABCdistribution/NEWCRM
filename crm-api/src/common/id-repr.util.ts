/**
 * Variantes d'écriture d'un code représentant, pour les comparaisons.
 * `User.idRepr` est stocké tel que lu dans l'AD (ex. « 68 »), alors que Minos
 * écrit sur 3 chiffres (« 068 ») : on compare donc sur toutes les formes
 * équivalentes, sans jamais modifier la valeur stockée.
 *   « 68 » → ['68', '068'] · « 003 » → ['003', '3'] · « 179 » → ['179']
 */
export function idReprVariants(code: string): string[] {
  const variants = new Set<string>([code]);
  if (/^\d+$/.test(code)) {
    variants.add(code.padStart(3, '0'));
    variants.add(String(Number(code)));
  }
  return [...variants];
}
