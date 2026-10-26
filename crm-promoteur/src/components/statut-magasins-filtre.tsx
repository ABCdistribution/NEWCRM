import Link from 'next/link';

export type StatutMagasins = 'actifs' | 'inactifs' | undefined;

const OPTIONS: { valeur: StatutMagasins; libelle: string }[] = [
  { valeur: undefined, libelle: 'Tous' },
  { valeur: 'actifs', libelle: 'Actifs' },
  { valeur: 'inactifs', libelle: 'Inactifs' },
];

/**
 * Filtre actif / inactif de la liste des magasins. Porté par `?statut=` et appliqué côté API (sur tous les
 * résultats, pas seulement la page affichée). Les autres paramètres de l'URL (recherche, portefeuille) sont conservés.
 */
export function StatutMagasinsFiltre({
  statut,
  params,
}: {
  statut: StatutMagasins;
  params: Record<string, string | undefined>;
}) {
  const href = (valeur: StatutMagasins) => {
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(params)) if (v) sp.set(k, v);
    if (valeur) sp.set('statut', valeur); // le changement de filtre repart de la page 1
    const q = sp.toString();
    return q ? `?${q}` : '?';
  };

  return (
    <div className="flex items-center gap-1.5" role="group" aria-label="Filtrer les magasins par état">
      <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">État</span>
      {OPTIONS.map((o) => {
        const actif = o.valeur === statut;
        return (
          <Link
            key={o.libelle}
            href={href(o.valeur)}
            aria-current={actif ? 'true' : undefined}
            className={`rounded-full border px-3 py-1 text-xs font-medium transition ${
              actif
                ? 'border-brand bg-brand text-white'
                : 'border-neutral-200 text-neutral-600 hover:bg-neutral-100'
            }`}
          >
            {o.libelle}
          </Link>
        );
      })}
    </div>
  );
}
