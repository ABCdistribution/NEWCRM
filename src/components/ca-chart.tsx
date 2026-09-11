const MOIS = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/** Format compact pour l'axe : 12 500 → « 12,5 k€ ». */
function compactEUR(v: number): string {
  if (v >= 1_000_000) return `${(v / 1_000_000).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} M€`;
  if (v >= 1_000) return `${(v / 1_000).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} k€`;
  return `${Math.round(v)} €`;
}

/** « Joli » plafond d'axe : 1/2/2,5/5 × 10^n au-dessus du max. */
function niceCeil(max: number): number {
  if (max <= 0) return 1;
  const pow = 10 ** Math.floor(Math.log10(max));
  for (const m of [1, 2, 2.5, 5, 10]) {
    if (m * pow >= max) return m * pow;
  }
  return 10 * pow;
}

/**
 * CA mensuel N vs N-1 — barres groupées, SVG rendu serveur.
 * Palette de marque : N = marine (#08184D), N-1 = cyan (#65FBFD, liseré marine pour la lisibilité sur blanc).
 * En mode sombre : N = cyan, N-1 = marine éclairci. Tooltips natifs <title>.
 */
export function CaChart({
  anneeN,
  courbeN,
  courbeN1,
}: {
  anneeN: number;
  courbeN: number[];
  courbeN1: number[];
}) {
  const max = Math.max(...courbeN, ...courbeN1);
  if (max <= 0) {
    return (
      <p className="px-5 py-8 text-center text-sm text-neutral-400">
        Aucun chiffre d&apos;affaires sur {anneeN - 1}–{anneeN} pour ce magasin.
      </p>
    );
  }

  // Géométrie
  const W = 720;
  const H = 220;
  const padL = 46;
  const padR = 8;
  const padT = 10;
  const padB = 24;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;
  const top = niceCeil(max);
  const groupW = plotW / 12;
  const barW = Math.min(14, (groupW - 8) / 2); // 2 barres + respiration par groupe
  const y = (v: number) => padT + plotH - (v / top) * plotH;

  const gridLines = [0.25, 0.5, 0.75, 1].map((f) => ({ v: top * f, y: y(top * f) }));

  return (
    <div className="px-3 pb-4 pt-2">
      {/* Légende (2 séries) */}
      <div className="mb-1 flex items-center justify-end gap-4 pr-2 text-xs text-neutral-500">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm border border-brand/40 bg-accent dark:border-transparent dark:bg-brand-light" />
          {anneeN - 1}
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm bg-brand dark:bg-accent" />
          {anneeN}
        </span>
      </div>

      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label={`Chiffre d'affaires mensuel ${anneeN - 1} et ${anneeN}`}>
        {/* Grille discrète + libellés d'axe */}
        {gridLines.map((g) => (
          <g key={g.v}>
            <line
              x1={padL}
              x2={W - padR}
              y1={g.y}
              y2={g.y}
              className="stroke-neutral-200 dark:stroke-navy-700"
              strokeWidth={1}
            />
            <text
              x={padL - 6}
              y={g.y + 3}
              textAnchor="end"
              className="fill-neutral-400 text-[10px]"
            >
              {compactEUR(g.v)}
            </text>
          </g>
        ))}
        {/* Ligne de base */}
        <line
          x1={padL}
          x2={W - padR}
          y1={padT + plotH}
          y2={padT + plotH}
          className="stroke-neutral-300 dark:stroke-navy-600"
          strokeWidth={1}
        />

        {MOIS.map((mois, i) => {
          const cx = padL + groupW * i + groupW / 2;
          const vN1 = courbeN1[i] ?? 0;
          const vN = courbeN[i] ?? 0;
          const baseY = padT + plotH;
          return (
            <g key={mois}>
              {/* N-1 (cyan) puis N (marine), séparées de 2px */}
              {vN1 > 0 ? (
                <rect
                  x={cx - barW - 1}
                  y={y(vN1)}
                  width={barW}
                  height={baseY - y(vN1)}
                  rx={3}
                  strokeWidth={1}
                  className="fill-accent stroke-brand/40 dark:fill-brand-light dark:stroke-transparent"
                >
                  <title>{`${mois} ${anneeN - 1} : ${EUR.format(vN1)}`}</title>
                </rect>
              ) : null}
              {vN > 0 ? (
                <rect
                  x={cx + 1}
                  y={y(vN)}
                  width={barW}
                  height={baseY - y(vN)}
                  rx={3}
                  className="fill-brand dark:fill-accent"
                >
                  <title>{`${mois} ${anneeN} : ${EUR.format(vN)}`}</title>
                </rect>
              ) : null}
              <text x={cx} y={H - 8} textAnchor="middle" className="fill-neutral-400 text-[10px]">
                {mois}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}
