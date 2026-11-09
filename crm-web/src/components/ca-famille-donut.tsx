import { Package } from 'lucide-react';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/**
 * Teintes de la couleur de marque, de la plus soutenue (1re famille) à la plus claire (« Autres »).
 * Chaque entrée porte le trait de l'arc et la pastille de la légende (classes écrites en toutes lettres
 * pour que Tailwind les détecte) : le graphe suit le thème (bleu / violet) sans aucune couleur en dur.
 */
const TEINTES = [
  { arc: 'stroke-brand', puce: 'bg-brand' },
  { arc: 'stroke-brand/80', puce: 'bg-brand/80' },
  { arc: 'stroke-brand/60', puce: 'bg-brand/60' },
  { arc: 'stroke-brand/45', puce: 'bg-brand/45' },
  { arc: 'stroke-brand/30', puce: 'bg-brand/30' },
  { arc: 'stroke-brand/20', puce: 'bg-brand/20' },
] as const;

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
      <div className="flex flex-wrap items-center gap-2 px-5 pt-4">
        <Package size={18} className="text-brand dark:text-accent" aria-hidden />
        <h2 className="text-sm font-semibold">Répartition du CA par famille</h2>
        <span className="ml-auto rounded-lg border border-neutral-200 px-3 py-1.5 text-sm font-medium dark:border-navy-700">
          {moisLabel}
        </span>
      </div>

      {total <= 0 || familles.length === 0 ? (
        <p className="px-5 py-16 text-center text-sm text-neutral-400">
          Aucune commande sur {moisLabel.toLowerCase()}.
        </p>
      ) : (
        <div className="flex flex-col items-center gap-5 px-5 py-5 sm:flex-row">
          <div className="relative shrink-0">
            <svg
              viewBox="0 0 100 100"
              className="h-44 w-44"
              role="img"
              aria-label={`Répartition du CA par famille : ${EUR.format(total)} au total`}
            >
              <circle cx={50} cy={50} r={R} fill="none" strokeWidth={14} className="stroke-neutral-100 dark:stroke-navy-700" />
              {familles.map((f, i) => {
                const longueur = (f.ca / total) * C;
                const arc = (
                  <circle
                    key={f.nom}
                    cx={50}
                    cy={50}
                    r={R}
                    fill="none"
                    strokeWidth={14}
                    strokeDasharray={`${longueur} ${C - longueur}`}
                    strokeDashoffset={-decalage}
                    transform="rotate(-90 50 50)"
                    className={TEINTES[Math.min(i, TEINTES.length - 1)].arc}
                  >
                    <title>{`${f.nom} : ${EUR.format(f.ca)} (${f.pct} %)`}</title>
                  </circle>
                );
                decalage += longueur;
                return arc;
              })}
            </svg>
            <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center" aria-hidden>
              <span className="text-lg font-bold tabular-nums">{EUR.format(total)}</span>
              <span className="text-xs text-neutral-500">CA total</span>
            </div>
          </div>

          <ul className="flex w-full min-w-0 flex-1 flex-col gap-2.5">
            {familles.map((f, i) => (
              <li key={f.nom} className="flex items-center gap-2.5 text-sm">
                <span
                  className={`h-3 w-3 shrink-0 rounded-full ${TEINTES[Math.min(i, TEINTES.length - 1)].puce}`}
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
