// Carte des régions commerciales de la force de vente : la MÊME carte que l'annuaire intranet
// (http://intranet.abcosmetique.com/annuaire/). Les tracés viennent de `carte-regions-fdv-formes.ts` (généré depuis
// l'annuaire) ; ce module les relie aux codes de région du CRM et fixe les libellés et la position des étiquettes.
// Fonctions pures, utilisables côté serveur ET client.
import { FORMES_ANNUAIRE } from './carte-regions-fdv-formes';

/** Dimensions du viewBox de la carte de l'annuaire. */
export const VIEWBOX_FDV_L = 700;
export const VIEWBOX_FDV_H = 720;

export type FormeRegionFdv = {
  /** Nom de la région dans l'annuaire (valeur de l'attribut AD `st`). */
  cle: string;
  /** Code de la région dans le CRM (`regions.code`, voir crm-api/src/common/regions.util.ts). */
  code: string;
  /** Libellé écrit sur la carte. */
  libelle: string;
  /** Précision sous le libellé (région hors France métropolitaine). */
  sousTitre: string | null;
  /** Tracé SVG. */
  d: string;
  /** Centroïde de la forme, où se place le libellé par défaut. */
  centre: readonly [number, number];
  /** Libellé déplacé hors de la forme (Corse) : position et trait de rappel vers l'île. */
  etiquette: { x: number; y: number; trait: readonly [readonly [number, number], readonly [number, number]] } | null;
};

/** Pour chaque région de l'annuaire : code CRM, libellé, sous-titre, étiquette déplacée. Ordre = ordre de dessin de l'annuaire. */
const REGLAGES: readonly {
  cle: string;
  code: string;
  libelle: string;
  sousTitre?: string;
  etiquette?: FormeRegionFdv['etiquette'];
}[] = [
  { cle: 'IDF', code: 'IDF', libelle: 'IDF' },
  { cle: 'NORD OUEST', code: 'NO', libelle: 'NORD OUEST' },
  { cle: 'NORD EST', code: 'NE', libelle: 'NORD EST' },
  { cle: 'SUD EST', code: 'SE', libelle: 'SUD EST' },
  { cle: 'SUD OUEST', code: 'SO', libelle: 'SUD OUEST' },
  { cle: 'BENELUX', code: 'BENELUX', libelle: 'BENELUX', sousTitre: 'Belgique' },
  // « AUTRE » dans l'annuaire est la Corse ; son libellé est posé en mer et relié à l'île par un trait.
  {
    cle: 'AUTRE',
    code: 'COR',
    libelle: 'CORSE',
    etiquette: {
      x: 566,
      y: 628,
      trait: [
        [600, 626],
        [633, 622],
      ],
    },
  },
];

export const FORMES_REGIONS_FDV: readonly FormeRegionFdv[] = REGLAGES.map((r) => {
  const forme = FORMES_ANNUAIRE[r.cle];
  if (!forme) throw new Error(`Forme de région manquante : ${r.cle}`);
  return {
    cle: r.cle,
    code: r.code,
    libelle: r.libelle,
    sousTitre: r.sousTitre ?? null,
    d: forme.d,
    centre: forme.centre,
    etiquette: r.etiquette ?? null,
  };
});

/** Forme d'une région du CRM d'après son code (`regions.code`), ou undefined (région sans tracé). */
export function formeRegionFdv(code: string): FormeRegionFdv | undefined {
  return FORMES_REGIONS_FDV.find((f) => f.code === code);
}
