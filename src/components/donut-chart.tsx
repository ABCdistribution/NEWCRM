export type DonutSegment = { label: string; value: number; color: string };

/**
 * Donut SVG (rendu serveur) — segments proportionnels, valeur au centre, légende.
 * Les couleurs sont passées en hex (sémantiques), lisibles en clair comme en sombre.
 */
export function DonutChart({
  segments,
  centerValue,
  centerLabel,
}: {
  segments: DonutSegment[];
  centerValue: string;
  centerLabel: string;
}) {
  const total = segments.reduce((s, x) => s + x.value, 0);
  const R = 40;
  const C = 2 * Math.PI * R;
  let offset = 0;

  return (
    <div className="flex flex-col items-center gap-3 px-5 py-4 sm:flex-row sm:gap-5">
      <div className="relative shrink-0">
        <svg viewBox="0 0 100 100" className="h-32 w-32" role="img" aria-label={centerLabel}>
          <circle cx={50} cy={50} r={R} fill="none" className="stroke-neutral-100 dark:stroke-navy-700" strokeWidth={13} />
          {total > 0
            ? segments.map((seg) => {
                if (seg.value <= 0) return null;
                const len = (seg.value / total) * C;
                const el = (
                  <circle
                    key={seg.label}
                    cx={50}
                    cy={50}
                    r={R}
                    fill="none"
                    stroke={seg.color}
                    strokeWidth={13}
                    strokeDasharray={`${len} ${C - len}`}
                    strokeDashoffset={-offset}
                    transform="rotate(-90 50 50)"
                  >
                    <title>{`${seg.label} : ${seg.value}`}</title>
                  </circle>
                );
                offset += len;
                return el;
              })
            : null}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="text-xl font-bold tabular-nums">{centerValue}</span>
          <span className="text-[10px] uppercase tracking-wide text-neutral-400">{centerLabel}</span>
        </div>
      </div>

      <ul className="flex w-full flex-col gap-1.5">
        {segments.map((seg) => (
          <li key={seg.label} className="flex items-center gap-2 text-sm">
            <span className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ backgroundColor: seg.color }} />
            <span className="flex-1 text-neutral-500">{seg.label}</span>
            <span className="font-semibold tabular-nums">{seg.value}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
