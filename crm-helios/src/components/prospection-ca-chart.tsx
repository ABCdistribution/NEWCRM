import Link from 'next/link';
import { Sprout } from 'lucide-react';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

const VIOLET = '#5B4FD1';
const LILAS = '#B9AEF3';

export type ProspectionSemaine = { label: string; ca: number | null; objectif: number | null };

type Prospection = {
  ouverts: number;
  pipelinePondere: number;
  semaines: ProspectionSemaine[];
};

/** Plus petit « beau » maximum (1, 2, 2.5, 5 × 10^k) pour 4 intervalles d'axe. */
function maxAxe(valeur: number): number {
  if (valeur <= 0) return 4;
  const brut = valeur / 4;
  const puissance = 10 ** Math.floor(Math.log10(brut));
  const pas = [1, 2, 2.5, 5, 10].map((m) => m * puissance).find((p) => p >= brut) ?? brut;
  return pas * 4;
}

/**
 * CA réalisé vs objectif côté PROSPECTION, par semaine du mois (valeurs cumulées) :
 * barres = CA facturé par les magasins issus de la prospection, courbe pointillée =
 * objectif (1/12e du potentiel signé, réparti linéairement sur le mois).
 */
export function ProspectionCaChart({ p, moisLabel }: { p: Prospection; moisLabel: string }) {
  const semaines = p.semaines;
  const valeurs = semaines.flatMap((s) => [s.ca ?? 0, s.objectif ?? 0]);
  const max = maxAxe(Math.max(...valeurs));
  const vide = valeurs.every((v) => v === 0);

  // Géométrie du graphe (viewBox fixe, mis à l'échelle en largeur).
  const W = 620;
  const H = 250;
  const gauche = 78;
  const droite = 16;
  const haut = 14;
  const bas = 32;
  const largeurUtile = W - gauche - droite;
  const hauteurUtile = H - haut - bas;
  const y = (v: number) => haut + hauteurUtile * (1 - v / max);
  const pas = largeurUtile / semaines.length;
  const cx = (i: number) => gauche + pas * (i + 0.5);
  const largeurBarre = Math.min(46, pas * 0.5);

  const points = semaines.flatMap((s, i) => (s.objectif != null ? [{ x: cx(i), y: y(s.objectif) }] : []));
  const courbe = points.map((pt, i) => `${i === 0 ? 'M' : 'L'}${pt.x},${pt.y}`).join(' ');

  return (
    <section className="rounded-2xl bg-white shadow-card">
      <div className="flex items-center gap-2 px-5 pt-4">
        <Sprout size={18} className="text-violet-600" aria-hidden />
        <h2 className="text-sm font-semibold">Prospection — CA réalisé vs objectif</h2>
        <span className="ml-auto rounded-lg border border-neutral-200 px-3 py-1.5 text-sm font-medium">{moisLabel}</span>
      </div>

      <div className="flex items-center justify-end gap-4 px-5 pt-2 text-xs text-neutral-600">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: VIOLET }} aria-hidden />
          CA réalisé
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span
            className="h-2.5 w-2.5 rounded-full border-2 bg-white"
            style={{ borderColor: LILAS }}
            aria-hidden
          />
          Objectif
        </span>
      </div>

      <div className="px-3 pb-1">
        {vide ? (
          <p className="px-2 py-16 text-center text-sm text-neutral-400">
            Aucune donnée de prospection sur {moisLabel.toLowerCase()}.
          </p>
        ) : (
          <svg viewBox={`0 0 ${W} ${H}`} className="h-auto w-full" role="img" aria-label="CA réalisé et objectif par semaine">
            {/* Grille et axe vertical */}
            {[0, 1, 2, 3, 4].map((k) => {
              const v = (max / 4) * k;
              return (
                <g key={k}>
                  <line x1={gauche} x2={W - droite} y1={y(v)} y2={y(v)} stroke="#E8EAF2" strokeWidth={1} />
                  <text x={gauche - 8} y={y(v) + 4} textAnchor="end" fontSize={11} fill="#6B7280">
                    {EUR.format(v)}
                  </text>
                </g>
              );
            })}
            {semaines.map((s, i) => (
              <line key={`v${s.label}`} x1={cx(i)} x2={cx(i)} y1={haut} y2={haut + hauteurUtile} stroke="#F0F1F7" strokeWidth={1} />
            ))}

            {/* Barres : CA réalisé cumulé */}
            {semaines.map((s, i) =>
              s.ca != null && s.ca > 0 ? (
                <rect
                  key={`b${s.label}`}
                  x={cx(i) - largeurBarre / 2}
                  y={y(s.ca)}
                  width={largeurBarre}
                  height={y(0) - y(s.ca)}
                  rx={4}
                  fill={VIOLET}
                >
                  <title>{`${s.label} — CA réalisé : ${EUR.format(s.ca)}`}</title>
                </rect>
              ) : null,
            )}

            {/* Courbe d'objectif */}
            {points.length > 1 ? (
              <path d={courbe} fill="none" stroke={LILAS} strokeWidth={2.5} strokeDasharray="7 6" strokeLinecap="round" />
            ) : null}
            {semaines.map((s, i) =>
              s.objectif != null ? (
                <circle key={`o${s.label}`} cx={cx(i)} cy={y(s.objectif)} r={5.5} fill="#fff" stroke={LILAS} strokeWidth={3}>
                  <title>{`${s.label} — objectif : ${EUR.format(s.objectif)}`}</title>
                </circle>
              ) : null,
            )}

            {/* Libellés des semaines */}
            {semaines.map((s, i) => (
              <text key={`x${s.label}`} x={cx(i)} y={H - 8} textAnchor="middle" fontSize={12} fill="#4B5563">
                {s.label}
              </text>
            ))}
          </svg>
        )}
      </div>

      <div className="flex items-center gap-3 border-t border-neutral-100 px-5 py-3 text-xs text-neutral-500">
        <span>
          <span className="font-semibold text-neutral-700">{EUR.format(p.pipelinePondere)}</span> de pipeline pondéré sur{' '}
          <span className="font-semibold text-neutral-700">{p.ouverts}</span> prospect{p.ouverts > 1 ? 's' : ''} en cours
        </span>
        <Link href="/pilotage/prospects" className="ml-auto font-medium text-violet-600 hover:underline">
          Ouvrir la prospection
        </Link>
      </div>
    </section>
  );
}
