/**
 * Régions commerciales FRANÇAISES reconnues dans l'attribut AD `st`.
 * Clé = libellé normalisé (minuscules, sans accents/espaces/tirets) ;
 * tout le reste (Piemonte, Belgique, vide…) est ignoré — pas de région.
 */
export const REGIONS_FR: Record<string, { code: string; nom: string }> = {
  sudest: { code: 'SE', nom: 'Sud-Est' },
  nordest: { code: 'NE', nom: 'Nord-Est' },
  nordouest: { code: 'NO', nom: 'Nord-Ouest' },
  sudouest: { code: 'SO', nom: 'Sud-Ouest' },
  idf: { code: 'IDF', nom: 'Île-de-France' },
  iledefrance: { code: 'IDF', nom: 'Île-de-France' },
  corse: { code: 'COR', nom: 'Corse' },
};

/** « Ile de France » / « Sud Est » / « IDF » → clé de REGIONS_FR. */
export function normalizeRegionLabel(label: string): string {
  return label
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // accents (diacritiques combinants)
    .toLowerCase()
    .replace(/[^a-z]/g, ''); // espaces, tirets…
}

/** Région française correspondant à un attribut `st`, ou null si hors périmètre. */
export function regionFromSt(label: string | null): { code: string; nom: string } | null {
  if (!label) return null;
  return REGIONS_FR[normalizeRegionLabel(label)] ?? null;
}
