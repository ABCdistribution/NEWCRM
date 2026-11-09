import { VIEWBOX_H, VIEWBOX_W, projeter, type FondDepartement } from '@/lib/carte-geo';

/** Région colorée du mode « équipes » (rendu pur : l'état est géré par le parent). */
export type RegionSvg = {
  id: string;
  nom: string;
  couleur: string;
  valeur: number;
  /** Codes des départements de la région. */
  codes: string[];
  /** Position du compteur (null = pas de tracé, la région n'est que dans la liste). */
  centre: { x: number; y: number } | null;
  selectionnee: boolean;
  attenuee: boolean;
};

/** Point positionné (mode « secteur »). */
export type PointSvg = {
  id: string;
  type: 'client' | 'prospect';
  x: number;
  y: number;
  attenue: boolean;
  selectionne: boolean;
};

type Props = {
  departements: FondDepartement[];
  /** Texte alternatif de toute la carte. */
  titre: string;
  regions?: RegionSvg[];
  onRegion?: (id: string) => void;
  /** Régions hors métropole (Benelux / Belgique) : forme simplifiée de la Belgique avec son chiffre. */
  bulles?: { id: string; nom: string; valeur: number; couleur: string }[];
  points?: PointSvg[];
  onPoint?: (type: 'client' | 'prospect', id: string) => void;
};

/** Belgique simplifiée (lon, lat) — polygone codé en dur, la Belgique n'est pas dans le GeoJSON. */
const BELGIQUE: [number, number][] = [
  [2.55, 51.09], [3.35, 51.37], [3.85, 51.22], [4.25, 51.37], [4.45, 51.48], [4.8, 51.43],
  [5.05, 51.47], [5.55, 51.3], [5.85, 51.05], [5.75, 50.75], [6.0, 50.55], [6.4, 50.33],
  [6.15, 50.12], [5.8, 49.55], [5.45, 49.5], [5.0, 49.8], [4.85, 50.15], [4.2, 49.95],
  [3.6, 50.35], [3.15, 50.75], [2.6, 50.82],
];
const BELGIQUE_PTS = BELGIQUE.map(([lon, lat]) => projeter(lon, lat));
const BELGIQUE_D = `M${BELGIQUE_PTS.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join('L')}Z`;
const BELGIQUE_CENTRE = {
  x: BELGIQUE_PTS.reduce((s, p) => s + p[0], 0) / BELGIQUE_PTS.length,
  y: BELGIQUE_PTS.reduce((s, p) => s + p[1], 0) / BELGIQUE_PTS.length,
};

const EST_CORSE = (codes: string[]) => codes.length > 0 && codes.every((c) => c === '2A' || c === '2B');
/** Emplacement du libellé de la Corse : en mer, à gauche de l'île, relié par un trait. */
const LIBELLE_CORSE = { x: 490, y: 565 };

/**
 * Carte de France en SVG pur. Chaque région est UNE forme unie : les départements sont dessinés avec
 * fill ET stroke de la même couleur (les coutures disparaissent), précédés d'un liseré blanc posé sous
 * la région (visible seulement entre deux régions voisines). Le survol / la sélection s'appliquent au
 * groupe entier. En mode secteur, des points (cercle = client, losange = prospect) sont posés par-dessus
 * un aplat gris très clair.
 */
export function CarteFranceSvg({ departements, titre, regions, onRegion, bulles, points, onPoint }: Props) {
  const parCode = new Map(departements.map((d) => [d.code, d]));
  const modePoints = !!points;
  const fondClasse = modePoints
    ? 'fill-neutral-100 stroke-neutral-100 dark:fill-navy-800 dark:stroke-navy-800'
    : 'fill-neutral-200 stroke-neutral-200 dark:fill-navy-800 dark:stroke-navy-800';

  // La région sélectionnée est dessinée en dernier (au-dessus de ses voisines).
  const regionsTriees = regions ? [...regions].sort((a, b) => Number(a.selectionnee) - Number(b.selectionnee)) : [];

  return (
    <svg
      viewBox={`0 0 ${VIEWBOX_W} ${VIEWBOX_H}`}
      role="group"
      aria-label={titre}
      className="mx-auto h-auto w-full max-w-[34rem]"
    >
      <title>{titre}</title>

      {/* Fond : un aplat unique (fill = stroke, aucune frontière interne) */}
      <g strokeWidth={1.4} strokeLinejoin="round" fillRule="evenodd">
        {departements.map((d) => (
          <path key={d.code} d={d.d} className={fondClasse} />
        ))}
      </g>

      {/* Mode équipes : régions pleines */}
      {regionsTriees.map((r) => {
        const deps = r.codes.map((c) => parCode.get(c)).filter((d): d is FondDepartement => !!d);
        if (deps.length === 0) return null;
        return (
          <g
            key={r.id}
            role="button"
            tabIndex={0}
            aria-pressed={r.selectionnee}
            aria-label={`${r.nom} : ${r.valeur} collaborateur${r.valeur > 1 ? 's' : ''}`}
            onClick={() => onRegion?.(r.id)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                onRegion?.(r.id);
              }
            }}
            opacity={r.attenuee ? 0.4 : 1}
            strokeLinejoin="round"
            fillRule="evenodd"
            className="cursor-pointer outline-none transition-opacity hover:opacity-80 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          >
            {/* 1. Liseré : blanc (ou brand si sélectionnée), sous tous les remplissages de la région */}
            {deps.map((d) => (
              <path
                key={`l-${d.code}`}
                d={d.d}
                fill="none"
                className={r.selectionnee ? 'stroke-brand' : 'stroke-white dark:stroke-navy-950'}
                strokeWidth={r.selectionnee ? 4.4 : 2.6}
              />
            ))}
            {/* 2. Remplissage : même couleur en fill et stroke, les coutures entre départements disparaissent */}
            {deps.map((d) => (
              <path key={`f-${d.code}`} d={d.d} fill={r.couleur} stroke={r.couleur} strokeWidth={r.selectionnee ? 2.2 : 1.2} />
            ))}
          </g>
        );
      })}

      {/* Belgique (Benelux) : forme simplifiée, uniquement si l'API renvoie la région */}
      {bulles?.map((b) => (
        <g key={b.id} role="img" aria-label={`${b.nom} : ${b.valeur} collaborateur${b.valeur > 1 ? 's' : ''}`}>
          <path
            d={BELGIQUE_D}
            fill={b.couleur}
            stroke={b.couleur}
            strokeWidth={1.2}
            strokeLinejoin="round"
          />
          <g textAnchor="middle" className="fill-navy-950" pointerEvents="none">
            <text x={BELGIQUE_CENTRE.x} y={BELGIQUE_CENTRE.y + 2} fontSize={16} fontWeight={700}>
              {b.valeur}
            </text>
            <text x={BELGIQUE_CENTRE.x} y={BELGIQUE_CENTRE.y + 12} fontSize={6.5}>
              {b.nom}
            </text>
          </g>
        </g>
      ))}

      {/* Compteurs au centre des régions (le chiffre et le nom ne reposent jamais sur la couleur seule) */}
      {regions?.map((r) => {
        if (!r.centre) return null;
        const corse = EST_CORSE(r.codes);
        const pos = corse ? LIBELLE_CORSE : r.centre;
        return (
          <g
            key={`t-${r.id}`}
            pointerEvents="none"
            opacity={r.attenuee ? 0.5 : 1}
            textAnchor="middle"
            className={corse ? 'fill-navy-950 dark:fill-white' : 'fill-navy-950'}
          >
            {corse ? (
              <line
                x1={pos.x + 38}
                y1={pos.y - 8}
                x2={r.centre.x}
                y2={r.centre.y}
                strokeWidth={1}
                className="stroke-neutral-400"
              />
            ) : null}
            <text x={pos.x} y={pos.y + 6} fontSize={corse ? 22 : 26} fontWeight={700}>
              {r.valeur}
            </text>
            <text x={pos.x} y={pos.y + 19} fontSize={8.5}>
              {corse ? `${r.nom} · collaborateurs` : 'collaborateurs'}
            </text>
          </g>
        );
      })}

      {/* Mode secteur : points */}
      {points?.map((p) => {
        const r = p.selectionne ? 6 : 4;
        const style = { opacity: p.attenue ? 0.25 : 1, cursor: 'pointer' } as const;
        const commun = {
          style,
          onClick: () => onPoint?.(p.type, p.id),
          // Les points sont réservés à la souris : la liste en dessous est l'équivalent clavier.
          'aria-hidden': true as const,
        };
        return p.type === 'client' ? (
          <circle
            key={`c-${p.id}`}
            cx={p.x}
            cy={p.y}
            r={r}
            strokeWidth={p.selectionne ? 2 : 1}
            className="fill-brand stroke-white dark:stroke-navy-950"
            {...commun}
          />
        ) : (
          <rect
            key={`p-${p.id}`}
            x={p.x - r}
            y={p.y - r}
            width={r * 2}
            height={r * 2}
            transform={`rotate(45 ${p.x} ${p.y})`}
            strokeWidth={p.selectionne ? 2 : 1}
            className="fill-accent stroke-white dark:stroke-navy-950"
            {...commun}
          />
        );
      })}
    </svg>
  );
}
