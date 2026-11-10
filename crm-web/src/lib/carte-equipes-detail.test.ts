import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { CarteEquipes } from '@/components/carte-equipes';
import type { Activite, CaADate, CarteEquipes as Donnees, CarteRegion, MembreRegion } from './carte';

// Détail d'une région sélectionnée (rendu par react-dom/server, région choisie par `regionInitiale`) : membres, rôles,
// activité du mois et comparaison du CA à l'objectif. Aucun mock : composants réels, données fabriquées.

const act = (visites: number, commandes: number, ca: number, objectif: number | null): Activite => ({
  visites,
  commandes,
  ca,
  objectif,
  tauxPct: objectif ? Math.round((ca / objectif) * 100) : null,
});
const membre = (id: string, nom: string, poste: string | null, a: Activite): MembreRegion => ({ id, displayName: nom, poste, ...a });
const vide = (id: string, code: string, nom: string, n: number): CarteRegion => ({
  id, code, nom, nbCollaborateurs: n, nbDirecteurs: 0, nbChefsSecteur: 0, nbPromoteurs: 0, nbClients: 0,
  stats: act(0, 0, 0, null), directeurs: [], chefsSecteur: [], promoteursHorsChef: [],
});

const NE: CarteRegion = {
  ...vide('r1', 'NE', 'Nord-Est', 6),
  nbDirecteurs: 1,
  nbChefsSecteur: 1,
  nbPromoteurs: 4,
  stats: act(41, 17, 31200, 36000),
  directeurs: [membre('d1', 'Cindy RENARD', 'Directrice Régionale des ventes', act(0, 0, 0, null))],
  chefsSecteur: [
    {
      ...membre('c1', 'Nadia HAMEL', 'Cheffe de secteur', act(9, 0, 0, null)),
      secteur: { id: 's1', code: 'NE', nom: 'Nord-Est' },
      nbClients: 42,
      promoteurs: [
        { ...membre('p1', 'Julien MARTIN', 'Promoteur des ventes', act(14, 8, 12400, 12000)), nbClients: 14 },
        { ...membre('p2', 'Léa PETIT', 'Promotrice des ventes', act(10, 6, 9100, 12500)), nbClients: 12 },
      ],
    },
  ],
  promoteursHorsChef: [{ ...membre('p4', 'Inès GARCIA', 'Promotrice des ventes', act(0, 0, 0, null)), nbClients: 0, chef: 'Karim BENALI' }],
};
const DONNEES: Donnees = {
  periode: { annee: 2026, mois: 11 },
  regions: [vide('r0', 'IDF', 'Île-de-France', 7), NE, vide('r2', 'BENELUX', 'Benelux', 3)],
};

const nbsp = (s: string) => s.replace(/[  ]/g, ' ');
const rendre = (regionInitiale: string | null, droits = { chef: true, promo: true }, caADate?: CaADate | null) =>
  nbsp(
    renderToStaticMarkup(
      createElement(CarteEquipes, {
        data: caADate === undefined ? DONNEES : { ...DONNEES, caADate },
        ficheChefSecteur: droits.chef,
        fichePromoteur: droits.promo,
        regionInitiale,
      }),
    ),
  );

describe('détail d’une région sélectionnée', () => {
  it('sans région sélectionnée : aucun détail', () => {
    const html = rendre(null);
    expect(html).not.toContain('Activité · ');
    expect(html).not.toContain('Cindy RENARD');
  });

  it('bilan du mois : visites, commandes, CA et comparaison à l’objectif', () => {
    const html = rendre('r1');
    expect(html).toContain('Activité · Novembre 2026');
    expect(html).toContain('>41<');
    expect(html).toContain('>17<');
    expect(html).toContain('31 200 €');
    expect(html).toContain('sur 36 000 €');
    expect(html).toContain('87 %');
    expect(html).toContain('CA comparé à l&#x27;objectif');
  });

  it('liste la direction, les chefs de secteur et les promoteurs avec leur rôle', () => {
    const html = rendre('r1');
    expect(html).toContain('>Direction<');
    expect(html).toContain('Cindy RENARD');
    expect(html).toContain('Directrice Régionale des ventes');
    expect(html).toContain('Nadia HAMEL');
    expect(html).toContain('Cheffe de secteur');
    expect(html).toContain('Julien MARTIN');
    expect(html).toContain('Promoteur des ventes');
    expect(html).toContain('Léa PETIT');
    expect(html).toContain('Promotrice des ventes');
  });

  it('chaque personne montre ses visites, commandes et son CA sur objectif', () => {
    const html = rendre('r1');
    expect(html).toContain('14 visites');
    expect(html).toContain('8 commandes');
    expect(html).toContain('12 400 €');
    expect(html).toContain('sur 12 000 €');
    expect(html).toContain('103 %');
    expect(html).toContain('73 %');
    // Une personne sans objectif le dit, sans pourcentage.
    expect(html).toContain('objectif non défini');
  });

  it('les promoteurs sans chef de la région sont listés à part, avec le nom de leur chef', () => {
    const html = rendre('r1');
    expect(html).toContain('Autres promoteurs de la région');
    expect(html).toContain('Inès GARCIA');
    expect(html).toContain('chef de secteur : Karim BENALI');
  });

  it('liens vers les fiches uniquement si le rôle y a droit (jamais pour la direction régionale)', () => {
    const avec = rendre('r1');
    expect(avec).toContain('href="/mon-equipe/c1"');
    expect(avec).toContain('href="/mon-equipe/promoteur/p1"');
    expect(avec).not.toContain('href="/mon-equipe/d1"');
    const sans = rendre('r1', { chef: false, promo: false });
    expect(sans).not.toContain('href="/mon-equipe/');
    expect(sans).toContain('Nadia HAMEL');
  });

  it('chaque personne a sa photo AD (proxy /avatar) avec ses initiales en repli', () => {
    const html = rendre('r1');
    for (const id of ['d1', 'c1', 'p1', 'p2', 'p4']) expect(html).toContain(`src="/avatar/${id}"`);
    expect(html).toContain('>CR<'); // Cindy RENARD
    expect(html).toContain('>NH<'); // Nadia HAMEL
    expect(html).toContain('>IG<'); // Inès GARCIA
  });

  it('sans région : carte et liste des secteurs visibles, pas de bouton de retour', () => {
    const html = rendre(null);
    expect(html).toContain('Carte des secteurs commerciaux');
    expect(html).toContain('Secteurs commerciaux');
    expect(html).not.toContain('Retour à la carte');
  });

  it('avec une région : la carte et la liste des secteurs sont repliées, un bouton ramène à la carte', () => {
    const html = rendre('r1');
    expect(html).not.toContain('Carte des secteurs commerciaux');
    expect(html).not.toContain('Secteurs commerciaux');
    expect(html).toContain('Retour à la carte');
    // Les pastilles de région restent pour changer de région sans rouvrir la carte.
    expect(html).toContain('aria-label="Filtrer par région"');
  });

  it('les pastilles de filtre portent le nom complet de la région, jamais son code abrégé', () => {
    const html = rendre(null);
    expect(html).toContain('Île-de-France (7)');
    expect(html).toContain('Nord-Est (6)');
    expect(html).toContain('Benelux (3)');
    expect(html).not.toContain('IDF (7)');
    expect(html).not.toContain('NE (6)');
  });

  it('CA réalisé / objectif à date, à côté de la recherche : état « bientôt disponible » tant que l’API ne le fournit pas', () => {
    const html = rendre(null);
    expect(html).toContain('CA réalisé / Objectif à date');
    expect(html).toContain('— / —');
    expect(html).toContain('bientôt disponible');
    // Affiché aussi quand une région est ouverte (il ne dépend pas de la carte), et placé avec la recherche.
    expect(rendre('r1')).toContain('CA réalisé / Objectif à date');
    expect(html.indexOf('type="search"')).toBeLessThan(html.indexOf('CA réalisé / Objectif à date'));
    expect(html.indexOf('CA réalisé / Objectif à date')).toBeLessThan(html.indexOf('Filtrer par région'));
  });

  it('CA réalisé / objectif à date avec donnée : montants, pourcentage et barre', () => {
    const html = rendre(null, undefined, { ca: 412000, objectif: 500000 });
    expect(html).toContain('412 000 €');
    expect(html).toContain('500 000 €');
    expect(html).toContain('82 %');
    expect(html).toContain('width:82%');
    expect(html).not.toContain('bientôt disponible');
  });

  it('pastilles, liste des secteurs et détail suivent l’ordre de l’annuaire, les régions inconnues à la fin', () => {
    // Données volontairement dans le désordre.
    const ordre: [string, string][] = [['COR', 'Corse'], ['NORD', 'Nord'], ['BENELUX', 'Benelux'], ['SO', 'Sud-Ouest'], ['SE', 'Sud-Est'], ['NE', 'Nord-Est'], ['NO', 'Nord-Ouest'], ['IDF', 'Île-de-France']];
    const desordre: Donnees = { periode: DONNEES.periode, regions: ordre.map(([code, nom], i) => vide('x' + i, code, nom, 10 + i)) };
    const html = nbsp(renderToStaticMarkup(createElement(CarteEquipes, { data: desordre, ficheChefSecteur: true, fichePromoteur: true })));
    const pastilles = html.slice(html.indexOf('Filtrer par région'), html.indexOf('Carte des secteurs'));
    const noms = ['Toutes', 'Île-de-France (17)', 'Nord-Ouest (16)', 'Nord-Est (15)', 'Sud-Est (14)', 'Sud-Ouest (13)', 'Benelux (12)', 'Corse (10)', 'Nord (11)'];
    const pos = noms.map((n) => pastilles.indexOf(n));
    expect(pos.every((p) => p >= 0)).toBe(true);
    expect([...pos].sort((a, b) => a - b)).toEqual(pos);
  });

  it('liste des secteurs : le CA du mois de chaque secteur sur son objectif, pas le nombre de collaborateurs, ni titre ni phrase d’explication', () => {
    const html = rendre(null);
    expect(html).not.toContain('Choisissez un secteur');
    expect(html).not.toContain('>Secteurs commerciaux<'); // aucun titre visible, seulement le nom accessible de la liste
    expect(html).toContain('aria-label="Secteurs commerciaux"');
    const panneau = html.slice(html.indexOf('aria-label="Secteurs commerciaux"'));
    // Nord-Est : CA 31 200 € sur 36 000 € (87 %) ; Île-de-France sans objectif : le dit.
    expect(panneau).toContain('CA <b class="font-semibold">31 200 €</b> sur 36 000 €');
    expect(panneau).toContain('objectif non défini');
    expect(panneau).not.toContain('collaborateurs');
    expect(html).not.toContain('répartis');
    expect(html).not.toContain('Cliquez sur');
    // La liste des secteurs est repliée avec la carte quand une région est ouverte.
    expect(rendre('r1')).not.toContain('aria-label="Secteurs commerciaux"');
  });

  it('la recherche remplace le titre visible (déjà en haut de page), qui reste pour les lecteurs d’écran', () => {
    const html = rendre(null);
    expect(html).toMatch(/<h2[^>]*class="sr-only"[^>]*>Les équipes Force de Vente<\/h2>/);
    expect(html).toContain('type="search"');
  });

  it('une région sans membre l’annonce', () => {
    const html = rendre('r2');
    expect(html).toContain('Aucun chef de secteur ni promoteur dans cette région.');
  });
});
