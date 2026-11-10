'use client';

import { useState } from 'react';
import { FORMES_REGIONS_FDV, VIEWBOX_FDV_H, VIEWBOX_FDV_L, type FormeRegionFdv } from '@/lib/carte-regions-fdv';
import { teinteRegion } from '@/lib/carte-palette';

/** Région du CRM à afficher sur la carte (les données viennent de l'API, déjà filtrées par périmètre). */
export type RegionCarte = {
  id: string;
  /** Code de région du CRM (`regions.code`) : il relie la région à sa forme. */
  code: string;
  nom: string;
  valeur: number;
  selectionnee: boolean;
  attenuee: boolean;
};

const pluriel = (n: number) => (n > 1 ? 'collaborateurs' : 'collaborateur');

/** Liseré blanc autour des textes posés sur la carte (le contour est peint sous le remplissage). */
const CONTOUR_TEXTE = {
  paintOrder: 'stroke',
  strokeWidth: 4,
  strokeOpacity: 0.9,
  strokeLinejoin: 'round',
} as const;

/**
 * Étiquette d'une région : libellé, précision éventuelle, effectif, « collaborateurs ». Deux jeux de tailles,
 * comme dans l'annuaire : `compact` (écrans étroits : libellé et effectif plus grands, rien d'autre) et normal.
 */
function Etiquette({
  forme,
  valeur,
  compact,
}: {
  forme: FormeRegionFdv;
  valeur: number;
  compact: boolean;
}) {
  const teinte = teinteRegion(forme.code);
  const x = forme.etiquette ? forme.etiquette.x : forme.centre[0];
  const y = forme.etiquette ? forme.etiquette.y : forme.centre[1];
  const sousTitre = compact ? null : forme.sousTitre;
  const tailleLibelle = compact ? 19 : 12;
  const tailleEffectif = compact ? 36 : 26;
  const ecartLibelle = compact ? 22 : 16;
  const ecartEffectif = compact ? 18 : 16;

  return (
    <g pointerEvents="none" textAnchor="middle">
      {forme.etiquette ? (
        <line
          x1={forme.etiquette.trait[0][0]}
          y1={forme.etiquette.trait[0][1]}
          x2={forme.etiquette.trait[1][0]}
          y2={forme.etiquette.trait[1][1]}
          stroke={teinte.texte}
          strokeWidth={1.2}
          strokeLinecap="round"
          opacity={0.55}
        />
      ) : null}
      <text
        x={x}
        y={y - ecartLibelle}
        fontSize={tailleLibelle}
        fontWeight={800}
        letterSpacing={1}
        fill={teinte.texte}
        className="stroke-white"
        style={CONTOUR_TEXTE}
      >
        {forme.libelle}
      </text>
      {sousTitre ? (
        <text
          x={x}
          y={y - 3}
          fontSize={9.5}
          fontWeight={700}
          className="fill-neutral-500 stroke-white"
          style={CONTOUR_TEXTE}
        >
          {sousTitre}
        </text>
      ) : null}
      <text
        x={x}
        y={y + (sousTitre ? 22 : ecartEffectif)}
        fontSize={tailleEffectif}
        fontWeight={900}
        className="fill-navy-950 stroke-white"
        style={CONTOUR_TEXTE}
      >
        {valeur}
      </text>
      {compact ? null : (
        <text
          x={x}
          y={y + (sousTitre ? 35 : 29)}
          fontSize={9}
          fontWeight={600}
          className="fill-neutral-500 stroke-white"
          style={CONTOUR_TEXTE}
        >
          {pluriel(valeur)}
        </text>
      )}
    </g>
  );
}

/**
 * Carte des régions commerciales : la même que l'annuaire intranet (mêmes formes, mêmes teintes, mêmes étiquettes,
 * Corse annotée par un trait, Belgique pour le Benelux). Une région est UNE forme ; survol, focus ou sélection la
 * colorent plus fort et la cernent d'un halo. Une région sans effectif est estompée et inactive ; une région absente
 * des données (hors périmètre de l'utilisateur) reste dessinée en gris neutre, sans étiquette.
 * Clavier : chaque région est un bouton (Entrée ou Espace). Pas de dégradé de fond.
 */
export function CarteRegionsSvg({
  regions,
  titre,
  onRegion,
}: {
  regions: RegionCarte[];
  titre: string;
  onRegion: (id: string) => void;
}) {
  const [survol, setSurvol] = useState<string | null>(null);
  const parCode = new Map(regions.map((r) => [r.code, r]));
  // Les formes qui ont des données, dans l'ordre de dessin de l'annuaire.
  const actives = FORMES_REGIONS_FDV.map((forme) => ({ forme, region: parCode.get(forme.code) })).filter(
    (x): x is { forme: FormeRegionFdv; region: RegionCarte } => x.region !== undefined,
  );
  const enAvant = (region: RegionCarte) => region.selectionnee || survol === region.code;

  return (
    <svg
      viewBox={`0 0 ${VIEWBOX_FDV_L} ${VIEWBOX_FDV_H}`}
      role="group"
      aria-label={titre}
      className="mx-auto block h-auto max-h-[74vh] w-full"
    >
      <title>{titre}</title>

      {/* Silhouette : toutes les formes en gris neutre (régions hors périmètre ou sans données). */}
      {FORMES_REGIONS_FDV.filter((f) => !parCode.has(f.code)).map((f) => (
        <path
          key={`n-${f.code}`}
          d={f.d}
          strokeWidth={2.5}
          strokeLinejoin="round"
          className="fill-neutral-100 stroke-white"
          aria-hidden
        />
      ))}

      {/* Régions avec données */}
      {actives.map(({ forme, region }) => {
        const teinte = teinteRegion(forme.code);
        const active = region.valeur > 0;
        return (
          <path
            key={`r-${forme.code}`}
            d={forme.d}
            role="button"
            tabIndex={active ? 0 : -1}
            aria-label={`${forme.libelle} : ${region.valeur} ${pluriel(region.valeur)}`}
            aria-disabled={!active}
            aria-pressed={region.selectionnee}
            strokeWidth={2.5}
            strokeLinejoin="round"
            style={{
              fill: enAvant(region) ? teinte.bord : teinte.fondFort,
              opacity: active ? (region.attenuee ? 0.4 : 1) : 0.5,
              cursor: active ? 'pointer' : 'default',
            }}
            // Pas de `outline-none` : en Tailwind 4 il force `outline-style: none` et annulerait le contour de focus.
            className="stroke-white transition-[fill,opacity] duration-200 motion-reduce:transition-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent"
            onMouseEnter={() => setSurvol(forme.code)}
            onMouseLeave={() => setSurvol((cur) => (cur === forme.code ? null : cur))}
            onFocus={() => setSurvol(forme.code)}
            onBlur={() => setSurvol((cur) => (cur === forme.code ? null : cur))}
            onClick={() => {
              if (active) onRegion(region.id);
            }}
            onKeyDown={(e) => {
              if (active && (e.key === 'Enter' || e.key === ' ')) {
                e.preventDefault();
                onRegion(region.id);
              }
            }}
          />
        );
      })}

      {/* Halo de la région survolée ou sélectionnée */}
      {actives
        .filter(({ region }) => enAvant(region))
        .map(({ forme }) => (
          <path
            key={`h-${forme.code}`}
            d={forme.d}
            fill="none"
            strokeWidth={2.5}
            strokeLinejoin="round"
            stroke={teinteRegion(forme.code).texte}
            opacity={0.9}
            pointerEvents="none"
            className="drop-shadow-lg"
          />
        ))}

      {/* Étiquettes : jeu normal à partir de 640 px, jeu compact en dessous (même seuil que l'annuaire) */}
      {actives.map(({ forme, region }) => (
        <g
          key={`e-${forme.code}`}
          opacity={region.attenuee ? 0.5 : region.valeur > 0 ? 1 : 0.55}
          className="transition-opacity motion-reduce:transition-none"
        >
          <g className="hidden sm:block">
            <Etiquette forme={forme} valeur={region.valeur} compact={false} />
          </g>
          <g className="sm:hidden">
            <Etiquette forme={forme} valeur={region.valeur} compact />
          </g>
        </g>
      ))}
    </svg>
  );
}
