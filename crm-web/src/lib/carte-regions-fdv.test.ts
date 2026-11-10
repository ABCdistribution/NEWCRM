import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { CarteRegionsSvg, type RegionCarte } from '@/components/carte-regions-svg';
import { teinteRegion } from './carte-palette';
import { FORMES_REGIONS_FDV, VIEWBOX_FDV_H, VIEWBOX_FDV_L, formeRegionFdv } from './carte-regions-fdv';

// Aucun mock : formes et palette réelles. Le rendu passe par react-dom/server (pas de navigateur).

/** Codes de région produits par l'API (crm-api/src/common/regions.util.ts) : la carte doit en avoir un tracé chacun. */
const CODES_API = ['IDF', 'NO', 'NE', 'SE', 'SO', 'BENELUX', 'COR'];

const region = (code: string, valeur: number, plus: Partial<RegionCarte> = {}): RegionCarte => ({
  id: `id-${code}`,
  code,
  nom: code,
  valeur,
  selectionnee: false,
  attenuee: false,
  ...plus,
});

const rendre = (regions: RegionCarte[]) =>
  renderToStaticMarkup(createElement(CarteRegionsSvg, { regions, titre: 'Carte test', onRegion: () => {} }));

describe('formes de la carte des régions (reprises de l’annuaire)', () => {
  it('une forme par région de l’API, sans doublon', () => {
    expect(FORMES_REGIONS_FDV.map((f) => f.code).sort()).toEqual([...CODES_API].sort());
    expect(new Set(FORMES_REGIONS_FDV.map((f) => f.cle)).size).toBe(7);
  });

  it('dessine dans l’ordre de l’annuaire', () => {
    expect(FORMES_REGIONS_FDV.map((f) => f.cle)).toEqual([
      'IDF',
      'NORD OUEST',
      'NORD EST',
      'SUD EST',
      'SUD OUEST',
      'BENELUX',
      'AUTRE',
    ]);
  });

  it('chaque tracé est un chemin SVG fermé dont le centroïde tient dans le viewBox', () => {
    for (const f of FORMES_REGIONS_FDV) {
      expect(f.d.startsWith('M'), f.cle).toBe(true);
      expect(f.d.endsWith('Z'), f.cle).toBe(true);
      expect(f.d.length, f.cle).toBeGreaterThan(500);
      expect(f.centre[0], f.cle).toBeGreaterThan(0);
      expect(f.centre[0], f.cle).toBeLessThan(VIEWBOX_FDV_L);
      expect(f.centre[1], f.cle).toBeGreaterThan(0);
      expect(f.centre[1], f.cle).toBeLessThan(VIEWBOX_FDV_H);
    }
  });

  it('« AUTRE » de l’annuaire est la Corse : libellé CORSE, étiquette en mer reliée à l’île', () => {
    const corse = formeRegionFdv('COR');
    expect(corse?.cle).toBe('AUTRE');
    expect(corse?.libelle).toBe('CORSE');
    expect(corse?.etiquette).toEqual({ x: 566, y: 628, trait: [[600, 626], [633, 622]] });
    // L’île est en bas à droite du viewBox.
    expect(corse!.centre[0]).toBeGreaterThan(600);
    expect(corse!.centre[1]).toBeGreaterThan(560);
  });

  it('le Benelux est annoncé « Belgique »', () => {
    expect(formeRegionFdv('BENELUX')?.sousTitre).toBe('Belgique');
    expect(formeRegionFdv('NE')?.sousTitre).toBeNull();
  });

  it('une région sans tracé n’a pas de forme', () => {
    expect(formeRegionFdv('NORD')).toBeUndefined();
  });
});

describe('teintes des régions (celles de l’annuaire)', () => {
  it('chaque région a la teinte de l’annuaire', () => {
    expect(teinteRegion('IDF').texte).toBe('#c2410c'); // orange
    expect(teinteRegion('NO').texte).toBe('#1d4ed8'); // bleu
    expect(teinteRegion('NE').texte).toBe('#6d28d9'); // violet
    expect(teinteRegion('SE').texte).toBe('#a16207'); // jaune
    expect(teinteRegion('SO').texte).toBe('#047857'); // émeraude
    expect(teinteRegion('BENELUX').texte).toBe('#0e7490'); // cyan
    expect(teinteRegion('COR').texte).toBe('#475569'); // ardoise
  });

  it('une région inconnue reçoit la teinte neutre', () => {
    expect(teinteRegion('NORD')).toEqual(teinteRegion('COR'));
  });
});

describe('rendu de la carte', () => {
  const toutes = FORMES_REGIONS_FDV.map((f, i) => region(f.code, [7, 12, 19, 14, 8, 3, 1][i]));

  it('affiche libellés, effectifs et accessibilité de chaque région', () => {
    const html = rendre(toutes);
    expect(html).toContain(`viewBox="0 0 ${VIEWBOX_FDV_L} ${VIEWBOX_FDV_H}"`);
    expect(html).toContain('aria-label="NORD OUEST : 12 collaborateurs"');
    expect(html).toContain('aria-label="NORD EST : 19 collaborateurs"');
    expect(html).toContain('aria-label="CORSE : 1 collaborateur"');
    expect(html).toContain('>CORSE<');
    expect(html).toContain('>Belgique<');
    expect(html).toContain('>collaborateurs<');
    // Les 7 formes sont des boutons.
    expect(html.match(/role="button"/g)).toHaveLength(7);
  });

  it('estompe et désactive une région sans effectif', () => {
    const html = rendre(toutes.map((r) => (r.code === 'BENELUX' ? { ...r, valeur: 0 } : r)));
    // L'ordre des attributs n'a pas d'importance : on isole la balise de la région.
    const balise = html.match(/<path[^>]*aria-label="BENELUX : 0 collaborateur"[^>]*>/)?.[0] ?? '';
    expect(balise).toContain('aria-disabled="true"');
    expect(balise).toContain('tabindex="-1"');
    expect(balise).toContain('opacity:0.5');
  });

  it('garde la silhouette grise des régions absentes des données (hors périmètre)', () => {
    const html = rendre([region('NE', 5)]);
    expect(html.match(/role="button"/g)).toHaveLength(1);
    // 6 silhouettes neutres, masquées aux lecteurs d’écran.
    expect(html.match(/aria-hidden="true"/g)?.length).toBe(6);
    expect(html).not.toContain('>CORSE<');
  });

  it('la région sélectionnée porte aria-pressed et un halo', () => {
    const html = rendre(toutes.map((r) => (r.code === 'SE' ? { ...r, selectionnee: true } : r)));
    expect(html.match(/aria-pressed="true"/g)).toHaveLength(1);
    expect(html).toContain('drop-shadow-lg');
    expect(rendre(toutes)).not.toContain('drop-shadow-lg');
  });

  it('les régions non sélectionnées sont atténuées quand une région l’est', () => {
    const html = rendre(toutes.map((r) => ({ ...r, attenuee: r.code !== 'NE' })));
    expect(html.match(/opacity:0\.4/g)).toHaveLength(6);
  });

  it('rend un jeu d’étiquettes normal et un jeu compact par région (seuil 640 px)', () => {
    const html = rendre(toutes);
    expect(html.match(/class="hidden sm:block"/g)).toHaveLength(7);
    expect(html.match(/class="sm:hidden"/g)).toHaveLength(7);
  });
});
