import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { BilanRegion, LigneActivite } from '@/components/activite-equipe';
import { euros, libellePeriode, libelleRole, niveauObjectif, phraseObjectif } from './activite';
import type { Activite } from './carte';

// Aucun mock : fonctions pures et rendu par react-dom/server (pas de navigateur).

const A = (plus: Partial<Activite> = {}): Activite => ({ visites: 12, commandes: 4, ca: 8450, objectif: 10000, tauxPct: 85, ...plus });
// Intl insère des espaces insécables : on les normalise pour comparer.
const nbsp = (s: string) => s.replace(/[  ]/g, ' ');

describe('formats de l’activité', () => {
  it('euros entiers à la française', () => {
    expect(nbsp(euros(8450))).toBe('8 450 €');
    expect(nbsp(euros(0))).toBe('0 €');
    expect(nbsp(euros(1234567))).toBe('1 234 567 €');
  });

  it('niveau d’objectif : 90 % et plus, 70 à 89 %, en dessous, ou aucun', () => {
    expect(niveauObjectif(120)).toBe('bon');
    expect(niveauObjectif(90)).toBe('bon');
    expect(niveauObjectif(89)).toBe('moyen');
    expect(niveauObjectif(70)).toBe('moyen');
    expect(niveauObjectif(69)).toBe('bas');
    expect(niveauObjectif(0)).toBe('bas');
    expect(niveauObjectif(null)).toBe('aucun');
  });

  it('mois affiché avec une majuscule', () => {
    expect(libellePeriode(2026, 11)).toBe('Novembre 2026');
    expect(libellePeriode(2026, 1)).toBe('Janvier 2026');
  });

  it('rôle : le poste de l’AD, sinon le libellé par défaut', () => {
    expect(libelleRole('Directrice nationale des ventes', 'Directeur régional')).toBe('Directrice nationale des ventes');
    expect(libelleRole('  Cheffe de secteur ', 'Chef de secteur')).toBe('Cheffe de secteur');
    expect(libelleRole(null, 'Promoteur')).toBe('Promoteur');
    expect(libelleRole('   ', 'Promoteur')).toBe('Promoteur');
  });

  it('phrase d’objectif lisible, avec ou sans objectif', () => {
    expect(nbsp(phraseObjectif(A()))).toBe("CA de 8 450 € sur 10 000 € d'objectif (85 %)");
    expect(nbsp(phraseObjectif(A({ objectif: null, tauxPct: null })))).toBe('CA de 8 450 €, objectif non défini');
  });
});

describe('rendu de l’activité', () => {
  it('ligne d’une personne : visites, commandes, CA sur objectif et pourcentage', () => {
    const html = nbsp(renderToStaticMarkup(createElement(LigneActivite, { a: A() })));
    expect(html).toContain('12 visites');
    expect(html).toContain('4 commandes');
    expect(html).toContain('8 450 €');
    expect(html).toContain('sur 10 000 €');
    expect(html).toContain('85 %');
    // La barre est décrite aux lecteurs d'écran et tracée à 85 %.
    expect(html).toContain('role="img"');
    expect(html).toContain("aria-label=\"CA de 8 450 € sur 10 000 € d&#x27;objectif (85 %)\"");
    expect(html).toContain('width:85%');
    expect(html).toContain('bg-amber-500');
  });

  it('singulier à 1 et pluriel au-delà', () => {
    const un = renderToStaticMarkup(createElement(LigneActivite, { a: A({ visites: 1, commandes: 1 }) }));
    expect(un).toContain('1 visite<');
    expect(un).toContain('1 commande<');
    const zero = renderToStaticMarkup(createElement(LigneActivite, { a: A({ visites: 0, commandes: 0 }) }));
    expect(zero).toContain('0 visite<');
  });

  it('sans objectif : le dit et ne trace pas de couleur d’atteinte', () => {
    const html = renderToStaticMarkup(createElement(LigneActivite, { a: A({ objectif: null, tauxPct: null }) }));
    expect(html).toContain('objectif non défini');
    expect(html).toContain('bg-neutral-300');
    expect(html).toContain('width:0%');
  });

  it('plafonne le tracé à 100 % mais écrit le pourcentage réel', () => {
    const html = renderToStaticMarkup(createElement(LigneActivite, { a: A({ ca: 15000, tauxPct: 150 }) }));
    expect(html).toContain('width:100%');
    expect(html).toContain('150 %');
    expect(html).toContain('bg-emerald-500');
  });

  it('un objectif très en retard est signalé en rouge', () => {
    const html = renderToStaticMarkup(createElement(LigneActivite, { a: A({ ca: 2000, tauxPct: 20 }) }));
    expect(html).toContain('bg-red-500');
    expect(html).toContain('text-red-700');
  });

  it('bilan de région : mois, visites, commandes, CA et comparaison à l’objectif', () => {
    const html = nbsp(renderToStaticMarkup(createElement(BilanRegion, { stats: A({ visites: 40, commandes: 15, ca: 31000, objectif: 36000, tauxPct: 86 }), annee: 2026, mois: 11 })));
    expect(html).toContain('Activité · Novembre 2026');
    expect(html).toContain('>Visites<');
    expect(html).toContain('>40<');
    expect(html).toContain('>Commandes<');
    expect(html).toContain('>15<');
    expect(html).toContain('31 000 €');
    expect(html).toContain('sur 36 000 €');
    expect(html).toContain('86 %');
    expect(html).toContain("CA comparé à l&#x27;objectif");
  });

  it('bilan de région sans objectif : « Objectif non défini pour cette région »', () => {
    const html = renderToStaticMarkup(createElement(BilanRegion, { stats: A({ objectif: null, tauxPct: null }), annee: 2026, mois: 11 }));
    expect(html).toContain('Objectif non défini pour cette région');
  });
});
