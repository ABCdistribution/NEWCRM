/**
 * Liens `mailto:` / `tel:` bâtis à partir de données d'API (import AS400, saisie de fiche) : on ne les insère
 * jamais tels quels. Un `?subject=…&body=…` glissé dans une adresse serait interprété par le client de
 * messagerie (brouillon pré-rempli) ; on valide donc la valeur avant de fabriquer le lien.
 */

// Lettres et chiffres Unicode, `.`, `_`, `+`, `'`, `-` en partie locale ; aucun caractère réservé d'URL
// (`?`, `&`, `#`, `%`…), espace, virgule ou point-virgule (liste de destinataires).
const ADRESSE = /^[\p{L}\p{N}._+'-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)*\.\p{L}{2,}$/u;

/** Adresse e-mail nettoyée (espaces retirés), ou `null` si elle n'a pas une forme sûre. */
export function adresseMail(valeur: string | null | undefined): string | null {
  const v = (valeur ?? '').trim();
  return v.length <= 254 && ADRESSE.test(v) ? v : null;
}

/** `mailto:` sûr pour cette adresse, ou `null` si elle est absente ou invalide. */
export function lienMailto(valeur: string | null | undefined): string | null {
  const adresse = adresseMail(valeur);
  return adresse ? `mailto:${encodeURI(adresse)}` : null;
}

/** `tel:` sûr (chiffres et `+` initial seulement), ou `null` s'il ne reste pas au moins 3 chiffres. */
export function lienTel(valeur: string | null | undefined): string | null {
  const v = (valeur ?? '').trim();
  const chiffres = v.replace(/\D/g, '');
  if (chiffres.length < 3 || chiffres.length > 20) return null;
  return `tel:${v.startsWith('+') ? '+' : ''}${chiffres}`;
}
