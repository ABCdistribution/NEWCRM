import Link from 'next/link';
import { hrefProduit } from '@/lib/produit-fiche';

/**
 * Lien vers la fiche d'un produit (`/produits/[id]`), dont le libellé est le nom accessible. Placé dans une cellule ou
 * une carte « relative », il en rend toute la surface cliquable (pseudo-élément `after`), avec un anneau de focus qui
 * entoure toute la ligne ou toute la carte au clavier. `rayon` : arrondi de la surface cliquable (cartes).
 */
export function LienProduit({
  id,
  libelle,
  className = '',
  rayon = '',
}: {
  id: string;
  libelle: string;
  className?: string;
  rayon?: string;
}) {
  return (
    <Link
      href={hrefProduit(id)}
      className={`after:absolute after:inset-0 ${rayon} focus-visible:outline-none focus-visible:after:outline-2 focus-visible:after:-outline-offset-2 focus-visible:after:outline-brand ${className}`}
    >
      {libelle}
    </Link>
  );
}
