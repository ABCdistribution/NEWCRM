import { Package } from 'lucide-react';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/** Dégradé de violets, du plus foncé (1re famille) au plus clair (« Autres »). */
const COULEURS = ['#4C3BB0', '#6C55DD', '#8F7BE8', '#B3A4F1', '#D3C9F7', '#E8E3FB'];

export type FamilleCa = { nom: string; ca: number; pct: number };

/** Répartition du CA du mois par famille d'articles : anneau + légende avec la part en %. */
export function CaFamilleDonut({
  data,
  moisLabel,
}: {
  data: { total: number; familles: FamilleCa[] };
  moisLabel: string;
}) {
  const { total, familles } = data;
  const R = 40;
  const C = 2 * Math.PI * R;
  let decalage = 0;

  return (
    <section className="h-full rounded-2xl bg-white shadow-card">
      <div className="flex items-center gap-2 px-5 pt-4">
        <Package size={18} className="text-violet-600" aria-hidden />
        <h2 className="text-sm font-semibold">Répartition du CA par famille</h2>
        <span className="ml-auto rounded-lg border border-neutral-200 px-3 py-1.5 text-sm font-medium">{moisLabel}</span>
      </div>

      {total <= 0 || familles.length === 0 ? (
        <p className="px-5 py-16 text-center text-sm text-neutral-400">
          Aucune commande sur {moisLabel.toLowerCase()}.
        </p>
      ) : (
        <div className="flex flex-col items-center gap-5 px-5 py-5 sm:flex-row">
          <div className="relative shrink-0">
            <svg viewBox="0 0 100 100" className="h-44 w-44" role="img" aria-label="Répartition du CA par famille">
              <circle cx={50} cy={50} r={R} fill="none" stroke="#F0F1F7" strokeWidth={14} />
              {familles.map((f, i) => {
                const longueur = (f.ca / total) * C;
                const arc = (
                  <circle
                    key={f.nom}
                    cx={50}
                    cy={50}
                    r={R}
                    fill="none"
                    stroke={COULEURS[Math.min(i, COULEURS.length - 1)]}
                    strokeWidth={14}
                    strokeDasharray={`${longueur} ${C - longueur}`}
                    strokeDashoffset={-decalage}
                    transform="rotate(-90 50 50)"
                  >
                    <title>{`${f.nom} : ${EUR.format(f.ca)} (${f.pct} %)`}</title>
                  </circle>
                );
                decalage += longueur;
                return arc;
              })}
            </svg>
            <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-lg font-bold tabular-nums">{EUR.format(total)}</span>
              <span className="text-xs text-neutral-500">CA total</span>
            </div>
          </div>

          <ul className="flex w-full min-w-0 flex-1 flex-col gap-2.5">
            {familles.map((f, i) => (
              <li key={f.nom} className="flex items-center gap-2.5 text-sm">
                <span
                  className="h-3 w-3 shrink-0 rounded-full"
                  style={{ backgroundColor: COULEURS[Math.min(i, COULEURS.length - 1)] }}
                  aria-hidden
                />
                <span className="min-w-0 flex-1 truncate text-neutral-600" title={f.nom}>
                  {f.nom}
                </span>
                <span className="font-semibold tabular-nums">{f.pct} %</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
