import { ChartColumn } from 'lucide-react';
import { formatEUR } from '@/lib/format';

export type MoisEvolution = { annee: number; mois: number; label: string; ca: number; commandes: number };

/** Plus petit « beau » maximum (1, 2, 2.5, 5 × 10^k) pour 4 intervalles d'axe. */
function maxAxe(valeur: number): number {
  if (valeur <= 0) return 4;
  const brut = valeur / 4;
  const puissance = 10 ** Math.floor(Math.log10(brut));
  const pas = [1, 2, 2.5, 5, 10].map((m) => m * puissance).find((p) => p >= brut) ?? brut;
  return pas * 4;
}

/**
 * Évolution du CA (barres, axe de gauche en €) et du nombre de commandes (courbe, axe de droite)
 * sur les 6 derniers mois.
 *
 * Couleurs : jetons du thème (`brand` pour le CA, `navy` pour la courbe : `brand-light` ne fait que 2,1:1
 * sur blanc), donc bleu / marine dans l'espace Promoteurs et violet / aubergine dans l'espace Direction.
 * SVG rendu côté serveur.
 */
export function EvolutionCaCommandes({ mois }: { mois: MoisEvolution[] }) {
  const maxCa = maxAxe(Math.max(...mois.map((m) => m.ca)));
  const maxCmd = maxAxe(Math.max(...mois.map((m) => m.commandes)));
  const vide = mois.every((m) => m.ca === 0 && m.commandes === 0);

  const W = 640;
  const H = 270;
  const gauche = 78;
  const droite = 44;
  const haut = 14;
  const bas = 32;
  const largeurUtile = W - gauche - droite;
  const hauteurUtile = H - haut - bas;
  const yCa = (v: number) => haut + hauteurUtile * (1 - v / maxCa);
  const yCmd = (v: number) => haut + hauteurUtile * (1 - v / maxCmd);
  const pas = largeurUtile / mois.length;
  const cx = (i: number) => gauche + pas * (i + 0.5);
  const largeurBarre = Math.min(48, pas * 0.5);
  const courbe = mois.map((m, i) => `${i === 0 ? 'M' : 'L'}${cx(i)},${yCmd(m.commandes)}`).join(' ');

  // Alternative textuelle : les valeurs du graphique, pour les lecteurs d'écran.
  const resume = mois
    .map((m) => `${m.label} ${m.annee} : ${formatEUR(m.ca)}, ${m.commandes} commande${m.commandes > 1 ? 's' : ''}`)
    .join(' ; ');

  return (
    <section className="rounded-2xl bg-white shadow-card">
      <div className="flex flex-wrap items-center gap-2 px-5 pt-4">
        <ChartColumn size={18} className="text-brand" aria-hidden />
        <h2 className="text-sm font-semibold">Évolution du CA et des commandes</h2>
        <span className="ml-auto rounded-lg border border-neutral-200 px-3 py-1.5 text-sm font-medium">6 derniers mois</span>
      </div>

      <div className="flex flex-wrap items-center justify-end gap-x-4 gap-y-1 px-5 pt-2 text-xs text-neutral-600">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full bg-brand" aria-hidden />
          CA réalisé (€)
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full border-2 border-navy bg-white" aria-hidden />
          Nombre de commandes
        </span>
      </div>

      <div className="px-3 pb-3">
        {vide ? (
          <p className="px-2 py-20 text-center text-sm text-neutral-400">Aucune commande sur les 6 derniers mois.</p>
        ) : (
          <svg
            viewBox={`0 0 ${W} ${H}`}
            className="h-auto w-full"
            role="img"
            aria-label={`CA et nombre de commandes par mois. ${resume}`}
          >
            {[0, 1, 2, 3, 4].map((k) => {
              const y = yCa((maxCa / 4) * k);
              return (
                <g key={k}>
                  <line x1={gauche} x2={W - droite} y1={y} y2={y} className="stroke-neutral-200" strokeWidth={1} />
                  <text x={gauche - 8} y={y + 4} textAnchor="end" fontSize={11} className="fill-neutral-500">
                    {formatEUR((maxCa / 4) * k)}
                  </text>
                  <text x={W - droite + 8} y={y + 4} textAnchor="start" fontSize={11} className="fill-neutral-500">
                    {Math.round((maxCmd / 4) * k)}
                  </text>
                </g>
              );
            })}

            {mois.map((m, i) =>
              m.ca > 0 ? (
                <rect
                  key={`b${m.annee}-${m.mois}`}
                  x={cx(i) - largeurBarre / 2}
                  y={yCa(m.ca)}
                  width={largeurBarre}
                  height={yCa(0) - yCa(m.ca)}
                  rx={3}
                  className="fill-brand"
                >
                  <title>{`${m.label} ${m.annee} — CA : ${formatEUR(m.ca)}`}</title>
                </rect>
              ) : null,
            )}

            <path d={courbe} fill="none" className="stroke-navy" strokeWidth={2.5} strokeLinejoin="round" strokeLinecap="round" />
            {mois.map((m, i) => (
              <circle
                key={`o${m.annee}-${m.mois}`}
                cx={cx(i)}
                cy={yCmd(m.commandes)}
                r={5}
                strokeWidth={2.5}
                className="fill-white stroke-navy"
              >
                <title>{`${m.label} ${m.annee} — ${m.commandes} commande${m.commandes > 1 ? 's' : ''}`}</title>
              </circle>
            ))}

            {mois.map((m, i) => (
              <text key={`x${m.annee}-${m.mois}`} x={cx(i)} y={H - 8} textAnchor="middle" fontSize={12} className="fill-neutral-600">
                {m.label}
              </text>
            ))}
          </svg>
        )}
      </div>
    </section>
  );
}
