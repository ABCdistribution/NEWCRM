'use client';

import { useState } from 'react';

type Groupe = {
  idRepr: string | null;
  promoteur: string;
  magasins: string[];
  totalMagasins: number;
};

/**
 * Camaïeu de la couleur de marque (jeton `brand`, qui suit l'espace : bleu Promoteurs, violet
 * Direction) + gris pour « Autres ». Les classes sont écrites en toutes lettres pour que Tailwind
 * les détecte ; « Autres » n'existe que lorsqu'il y a 6 promoteurs en tête, donc il tombe toujours
 * sur la dernière entrée.
 */
const COULEURS = [
  { trait: 'stroke-brand', pastille: 'bg-brand' },
  { trait: 'stroke-brand/80', pastille: 'bg-brand/80' },
  { trait: 'stroke-brand/60', pastille: 'bg-brand/60' },
  { trait: 'stroke-brand/45', pastille: 'bg-brand/45' },
  { trait: 'stroke-brand/30', pastille: 'bg-brand/30' },
  { trait: 'stroke-brand/20', pastille: 'bg-brand/20' },
  { trait: 'stroke-neutral-400', pastille: 'bg-neutral-400' },
];
const MAX_SEGMENTS = 6;

/**
 * Magasins ayant commandé ce mois, par promoteur — donut interactif : la part
 * de chaque promoteur en segments, le total au centre, et une légende qui
 * s'illumine au survol ou au focus clavier (les enseignes du promoteur en infobulle).
 */
export function CommandesParPromoteur({ groupes }: { groupes: Groupe[] }) {
  const [actif, setActif] = useState<number | null>(null);

  if (groupes.length === 0) {
    return <p className="px-5 py-6 text-sm text-neutral-400">Aucune commande ce mois.</p>;
  }

  // Top promoteurs + agrégat « Autres » pour garder un donut lisible.
  const tetes = groupes.slice(0, MAX_SEGMENTS);
  const reste = groupes.slice(MAX_SEGMENTS);
  const segments = [
    ...tetes.map((g) => ({
      nom: g.promoteur,
      valeur: g.totalMagasins,
      magasins: g.magasins,
      caches: g.totalMagasins - g.magasins.length,
    })),
    ...(reste.length
      ? [{
          nom: `Autres (${reste.length} promoteurs)`,
          valeur: reste.reduce((s, g) => s + g.totalMagasins, 0),
          magasins: reste.map((g) => g.promoteur),
          caches: 0,
        }]
      : []),
  ];
  const total = segments.reduce((s, x) => s + x.valeur, 0);

  // Donut en SVG : un arc par segment (cercle + dasharray), petit espace entre arcs.
  const R = 54;
  const EPAISSEUR = 18;
  const C = 2 * Math.PI * R;
  const ESPACE = segments.length > 1 ? 2.5 : 0;
  let cumul = 0;

  const centre = actif != null ? segments[actif] : null;

  return (
    <div className="flex flex-col items-center gap-5 px-5 py-4 sm:flex-row sm:items-center">
      <div className="relative shrink-0">
        <svg width="150" height="150" viewBox="0 0 150 150" role="img" aria-label="Répartition des clients commandants par promoteur">
          {segments.map((seg, i) => {
            const frac = seg.valeur / total;
            const longueur = Math.max(frac * C - ESPACE, 1);
            const offset = -cumul * C;
            cumul += frac;
            return (
              <circle
                key={`${seg.nom}-${i}`}
                cx="75"
                cy="75"
                r={R}
                fill="none"
                strokeWidth={actif === i ? EPAISSEUR + 4 : EPAISSEUR}
                strokeDasharray={`${longueur} ${C - longueur}`}
                strokeDashoffset={offset - ESPACE / 2}
                transform="rotate(-90 75 75)"
                opacity={actif == null || actif === i ? 1 : 0.3}
                className={`${COULEURS[i % COULEURS.length].trait} cursor-pointer transition-all duration-150`}
                onMouseEnter={() => setActif(i)}
                onMouseLeave={() => setActif(null)}
              />
            );
          })}
        </svg>
        {/* Centre : total, ou le promoteur survolé */}
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center text-center">
          <span className="text-2xl font-bold tabular-nums leading-none">{centre ? centre.valeur : total}</span>
          <span className="mt-1 max-w-24 truncate text-[10px] text-neutral-400">
            {centre ? centre.nom.split(' ')[0] : 'clients'}
          </span>
        </div>
      </div>

      {/* Légende interactive */}
      <ul className="min-w-0 flex-1 self-stretch">
        {segments.map((seg, i) => (
          <li key={`${seg.nom}-${i}`}>
            <button
              type="button"
              onMouseEnter={() => setActif(i)}
              onMouseLeave={() => setActif(null)}
              onFocus={() => setActif(i)}
              onBlur={() => setActif(null)}
              title={[...seg.magasins, ...(seg.caches > 0 ? [`+${seg.caches} autres`] : [])].join('\n')}
              className={`flex w-full items-center gap-2.5 rounded-lg px-2 py-1.5 text-left transition focus-visible:outline-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${actif === i ? 'bg-neutral-50 dark:bg-navy-800' : ''}`}
            >
              <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${COULEURS[i % COULEURS.length].pastille}`} aria-hidden />
              <span className="min-w-0 flex-1 truncate text-sm">{seg.nom}</span>
              <span className="shrink-0 text-sm font-semibold tabular-nums">{seg.valeur}</span>
              <span className="w-9 shrink-0 text-right text-xs tabular-nums text-neutral-400">
                {Math.round((seg.valeur / total) * 100)} %
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
