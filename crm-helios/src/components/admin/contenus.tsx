import Link from 'next/link';
import { Newspaper, PackageSearch, Percent, ShieldAlert } from 'lucide-react';

const CONTENUS = [
  { href: '/pilotage/promos', titre: 'Promos / PEM', detail: 'Promotions, mises en avant et PEM visibles par les promoteurs et l’app mobile.', icone: Percent },
  { href: '/pilotage/produits', titre: 'Produits', detail: 'Catalogue articles, familles et tarifs.', icone: PackageSearch },
  { href: '/pilotage/qualite', titre: 'Qualité & rappels produits', detail: 'Produits en rappel et retours autorisés.', icone: ShieldAlert },
  { href: '/pilotage/news', titre: 'Les News', detail: 'Actualités affichées aux équipes.', icone: Newspaper },
];

/** Point d'entrée vers les contenus métier, éparpillés dans le menu jusqu'ici. */
export function AdminContenusOnglet() {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
      {CONTENUS.map(({ href, titre, detail, icone: Icone }) => (
        <Link
          key={href}
          href={href}
          className="flex items-start gap-3 rounded-2xl bg-white p-5 shadow-card transition hover:ring-1 hover:ring-violet-200"
        >
          <span className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-violet-50 text-violet-600">
            <Icone size={20} aria-hidden />
          </span>
          <span>
            <span className="block text-sm font-semibold">{titre}</span>
            <span className="mt-0.5 block text-sm text-neutral-500">{detail}</span>
          </span>
        </Link>
      ))}
    </div>
  );
}
