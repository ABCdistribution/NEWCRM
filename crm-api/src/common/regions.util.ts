/**
 * Régions commerciales de la force de vente reconnues dans l'attribut AD `st` : les mêmes que dans l'annuaire
 * intranet (Sud-Est, Nord-Est, Nord-Ouest, Sud-Ouest, Île-de-France, Corse, Benelux).
 * Clé = libellé normalisé (minuscules, sans accents/espaces/tirets) ;
 * tout le reste (Piemonte, vide…) est ignoré — pas de région.
 * Ces codes sont aussi ceux de la carte des équipes de crm-web (crm-web/src/lib/carte-regions-fdv.ts) : ne pas les
 * renommer sans mettre la carte à jour.
 */
export const REGIONS_FR: Record<string, { code: string; nom: string }> = {
  sudest: { code: 'SE', nom: 'Sud-Est' },
  nordest: { code: 'NE', nom: 'Nord-Est' },
  nordouest: { code: 'NO', nom: 'Nord-Ouest' },
  sudouest: { code: 'SO', nom: 'Sud-Ouest' },
  idf: { code: 'IDF', nom: 'Île-de-France' },
  iledefrance: { code: 'IDF', nom: 'Île-de-France' },
  corse: { code: 'COR', nom: 'Corse' },
  // Dans l'AD, la valeur de `st` des comptes belges est « Belgique » ; l'annuaire intranet les range sous « BENELUX ».
  benelux: { code: 'BENELUX', nom: 'Benelux' },
  belgique: { code: 'BENELUX', nom: 'Benelux' },
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
