'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';

export type PointMagasin = {
  id: string;
  nom: string;
  ville: string | null;
  niveauClass: string | null;
  objectifMensuel: number;
  caMois: number;
};

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const EUR_COURT = (v: number) => (v >= 1000 ? `${Math.round(v / 1000)} k€` : `${v} €`);

// Géométrie du SVG (viewBox fixe, rendu responsive).
const L = 560;
const H = 340;
const M = { haut: 14, droite: 18, bas: 40, gauche: 56 };

/**
 * Nuage de points « objectif vs réalisé » des points de vente : X = objectif
 * mensuel, Y = CA facturé du mois, diagonale à 45°. Sous la diagonale :
 * magasin en retard → relance commerciale ou opération promotionnelle.
 */
export function ScatterObjectif({ points }: { points: PointMagasin[] }) {
  const [actif, setActif] = useState<PointMagasin | null>(null);

  const { max, enRetard } = useMemo(() => {
    const maxVal = Math.max(...points.map((p) => Math.max(p.objectifMensuel, p.caMois)), 1000);
    return {
      // Même échelle sur les deux axes pour que la diagonale ait un sens.
      max: maxVal * 1.05,
      enRetard: points.filter((p) => p.caMois < p.objectifMensuel).length,
    };
  }, [points]);

  if (points.length === 0) {
    return <p className="px-5 py-6 text-sm text-neutral-400">Aucun magasin avec objectif défini.</p>;
  }

  const x = (v: number) => M.gauche + (v / max) * (L - M.gauche - M.droite);
  const y = (v: number) => H - M.bas - (v / max) * (H - M.haut - M.bas);
  const graduations = [0.25, 0.5, 0.75, 1].map((f) => f * max);

  return (
    <div className="flex flex-col gap-1 px-5 py-4">
      <div className="relative">
        <svg viewBox={`0 0 ${L} ${H}`} className="w-full" role="img" aria-label="Objectif vs CA réalisé par magasin">
          {/* Grille + axes */}
          {graduations.map((g) => (
            <g key={g}>
              <line x1={x(g)} y1={M.haut} x2={x(g)} y2={H - M.bas} stroke="currentColor" className="text-neutral-100 dark:text-navy-800" />
              <line x1={M.gauche} y1={y(g)} x2={L - M.droite} y2={y(g)} stroke="currentColor" className="text-neutral-100 dark:text-navy-800" />
              <text x={x(g)} y={H - M.bas + 16} textAnchor="middle" className="fill-neutral-400 text-[10px]">{EUR_COURT(g)}</text>
              <text x={M.gauche - 6} y={y(g) + 3} textAnchor="end" className="fill-neutral-400 text-[10px]">{EUR_COURT(g)}</text>
            </g>
          ))}
          <text x={(L + M.gauche - M.droite) / 2} y={H - 4} textAnchor="middle" className="fill-neutral-500 text-[11px] font-medium">
            Objectif de CA (mensuel)
          </text>
          <text x={12} y={(H - M.bas + M.haut) / 2} textAnchor="middle" transform={`rotate(-90 12 ${(H - M.bas + M.haut) / 2})`} className="fill-neutral-500 text-[11px] font-medium">
            CA réalisé (mois)
          </text>

          {/* Diagonale 45° : au-dessus = objectif atteint, en dessous = à relancer */}
          <line x1={x(0)} y1={y(0)} x2={x(max)} y2={y(max)} stroke="currentColor" strokeDasharray="6 4" className="text-neutral-300 dark:text-navy-600" strokeWidth="1.5" />

          {/* Points */}
          {points.map((p) => {
            const retard = p.caMois < p.objectifMensuel;
            const surligne = actif?.id === p.id;
            return (
              <circle
                key={p.id}
                cx={x(p.objectifMensuel)}
                cy={y(p.caMois)}
                r={surligne ? 6 : 4}
                className={`cursor-pointer transition-all ${retard ? 'fill-red-400/70' : 'fill-emerald-500/70'} ${surligne ? 'stroke-2' : ''}`}
                stroke={surligne ? 'currentColor' : 'none'}
                onMouseEnter={() => setActif(p)}
                onMouseLeave={() => setActif(null)}
              />
            );
          })}
        </svg>

        {/* Infobulle */}
        {actif ? (
          <div
            className="pointer-events-none absolute z-10 -translate-x-1/2 rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-xs shadow-lg dark:border-navy-700 dark:bg-navy-900"
            style={{
              left: `${(x(actif.objectifMensuel) / L) * 100}%`,
              top: `calc(${(y(actif.caMois) / H) * 100}% - 3.6rem)`,
            }}
          >
            <p className="font-semibold">
              {actif.nom}
              {actif.niveauClass ? <span className="ml-1 text-neutral-400">({actif.niveauClass})</span> : null}
            </p>
            <p className="text-neutral-500">
              {EUR.format(actif.caMois)} / obj. {EUR.format(actif.objectifMensuel)}
              {actif.caMois < actif.objectifMensuel ? <span className="ml-1 font-semibold text-red-500">à relancer</span> : null}
            </p>
          </div>
        ) : null}
      </div>

      {/* Légende + lien d'action */}
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-neutral-500">
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-emerald-500/70" /> Objectif atteint ou dépassé</span>
        <span className="inline-flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full bg-red-400/70" /> Sous la diagonale — relance ou OP ({enRetard})</span>
        <Link href="/pilotage/magasins" className="ml-auto font-medium text-brand hover:underline dark:text-accent">
          Ouvrir les magasins
        </Link>
      </div>
    </div>
  );
}
