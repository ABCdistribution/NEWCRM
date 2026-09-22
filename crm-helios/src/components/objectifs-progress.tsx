const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

type Ligne = {
  nom: string;
  secteur: { nom: string } | null;
  ca: number;
  objectif: number | null;
  tauxPct: number | null;
  isActive: boolean;
};

function couleur(taux: number): string {
  if (taux >= 100) return 'bg-emerald-500';
  if (taux >= 70) return 'bg-amber-400';
  return 'bg-red-400';
}

/**
 * Atteinte des objectifs du mois : barre consolidée + une barre par promoteur
 * (CA réalisé vs objectif mensuel). Le repère vertical marque les 100 %.
 */
export function ObjectifsProgress({ classement }: { classement: Ligne[] }) {
  const lignes = classement
    .filter((p) => p.isActive && p.objectif != null && p.objectif > 0)
    .sort((a, b) => (b.tauxPct ?? 0) - (a.tauxPct ?? 0));

  if (lignes.length === 0) {
    return (
      <p className="px-5 py-8 text-sm text-neutral-400">
        Aucun objectif défini — les objectifs arrivent par API (import).
      </p>
    );
  }

  const caTotal = lignes.reduce((s, p) => s + p.ca, 0);
  const objectifTotal = lignes.reduce((s, p) => s + (p.objectif ?? 0), 0);
  const tauxGlobal = objectifTotal > 0 ? Math.round((caTotal / objectifTotal) * 100) : 0;

  const Barre = ({ taux }: { taux: number }) => (
    <div className="relative h-2.5 w-full overflow-hidden rounded-full bg-neutral-100 dark:bg-navy-800">
      <div
        className={`h-full rounded-full ${couleur(taux)} transition-all`}
        style={{ width: `${Math.min(taux, 130) / 1.3}%` }}
      />
      {/* Repère 100 % (à 100/130 de la largeur, l'échelle plafonne à 130 %) */}
      <span className="absolute inset-y-0 border-l border-neutral-300 dark:border-navy-600" style={{ left: `${100 / 1.3}%` }} />
    </div>
  );

  return (
    <div className="flex flex-col gap-4 px-5 py-4">
      {/* Consolidé */}
      <div>
        <div className="mb-1.5 flex items-baseline justify-between">
          <span className="text-sm font-semibold">Force de vente</span>
          <span className="text-sm tabular-nums">
            <span className="font-bold">{EUR.format(caTotal)}</span>
            <span className="text-neutral-400"> / {EUR.format(objectifTotal)}</span>
            <span className={`ml-2 font-bold ${tauxGlobal >= 100 ? 'text-emerald-500' : tauxGlobal >= 70 ? 'text-amber-500' : 'text-red-400'}`}>
              {tauxGlobal} %
            </span>
          </span>
        </div>
        <Barre taux={tauxGlobal} />
      </div>

      {/* Par promoteur */}
      <ul className="flex flex-col gap-2.5">
        {lignes.map((p) => {
          const taux = p.tauxPct ?? 0;
          return (
            <li key={`${p.nom}-${p.secteur?.nom ?? ''}`}>
              <div className="mb-1 flex items-baseline justify-between gap-2">
                <span className="min-w-0 truncate text-xs font-medium">
                  {p.nom}
                  {p.secteur ? <span className="ml-1.5 text-[10px] font-normal text-neutral-400">{p.secteur.nom}</span> : null}
                </span>
                <span className="shrink-0 text-xs tabular-nums text-neutral-500">
                  {EUR.format(p.ca)} / {EUR.format(p.objectif!)}
                  <span className={`ml-1.5 font-semibold ${taux >= 100 ? 'text-emerald-500' : taux >= 70 ? 'text-amber-500' : 'text-red-400'}`}>
                    {taux} %
                  </span>
                </span>
              </div>
              <Barre taux={taux} />
            </li>
          );
        })}
      </ul>
    </div>
  );
}
