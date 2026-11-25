import { describe, expect, it } from 'vitest';
import type { ArticleDetail } from './api';
import { FIL } from '@/test/produit-exemple';
import {
  NON_DEFINIE,
  VIDE,
  etatStock,
  formaterMontant,
  formaterNombre,
  hrefProduit,
  libelleTva,
  lignesInformations,
  periodePromo,
  texteOuNonDefinie,
  texteOuTiret,
} from './produit-fiche';

/** Normalise les espaces insécables des formats français (« 1 234,50 € ») pour comparer simplement. */
const normal = (texte: string): string => texte.replace(/[\u00a0\u202f]/g, ' ');

describe('libelleTva', () => {
  it.each(['1', '01', '001', '0001', ' 001 '])('code « %s » : Taux normal (zéros de tête ignorés)', (code) => {
    expect(libelleTva(code)).toBe('Taux normal');
  });

  it.each([
    ['2', 'Code 2'],
    ['002', 'Code 002'],
    ['10', 'Code 10'],
    ['0', 'Code 0'],
    ['00', 'Code 00'],
    ['A', 'Code A'],
    ['11', 'Code 11'],
    [' 3 ', 'Code 3'],
  ])('autre code « %s » : affiché tel quel (« %s »), aucun libellé inventé', (code, attendu) => {
    expect(libelleTva(code)).toBe(attendu);
  });

  it.each([null, undefined, '', '   '])('code absent (%j) : « — »', (code) => {
    expect(libelleTva(code)).toBe(VIDE);
  });
});

describe('texteOuTiret / texteOuNonDefinie', () => {
  it('valeur renseignée : rendue telle quelle (espaces de bord retirés)', () => {
    expect(texteOuTiret('MERCERIE')).toBe('MERCERIE');
    expect(texteOuTiret('  MERCERIE ')).toBe('MERCERIE');
    expect(texteOuNonDefinie('FIL MERCERIE')).toBe('FIL MERCERIE');
  });

  it.each([null, undefined, '', '   '])('valeur vide (%j) : « — » ou « non définie »', (valeur) => {
    expect(texteOuTiret(valeur)).toBe('—');
    expect(texteOuNonDefinie(valeur)).toBe('non définie');
    expect(NON_DEFINIE).toBe('non définie');
  });

  it('un zéro est une valeur, pas un vide', () => {
    expect(texteOuTiret('0')).toBe('0');
  });
});

describe('etatStock', () => {
  it.each([
    [0, null, 'rupture', 'Rupture'],
    [-3, 12, 'rupture', 'Rupture'],
    [5, 12, 'faible', 'Faible'],
    [11, 12, 'faible', 'Faible'],
    [12, 12, 'ok', 'OK'],
    [323, 12, 'ok', 'OK'],
    [5, null, 'ok', 'OK'], // PCB inconnu : jamais « faible »
    [5, 0, 'ok', 'OK'],
  ] as const)('stock %i, PCB %s : %s', (stock, pcb, etat, label) => {
    expect(etatStock(stock, pcb)).toMatchObject({ etat, label });
  });

  it('les trois états ont des couleurs sémantiques de statut (rouge, orange, vert), pas de jeton de thème', () => {
    expect(etatStock(0, null).tone).toContain('red');
    expect(etatStock(1, 12).tone).toContain('amber');
    expect(etatStock(20, 12).tone).toContain('emerald');
  });
});

describe('formats', () => {
  it('montant en euros, deux décimales au moins, séparateurs français', () => {
    expect(normal(formaterMontant(3.5))).toBe('3,50 €');
    expect(normal(formaterMontant(0))).toBe('0,00 €');
    expect(normal(formaterMontant(1234.5))).toBe('1 234,50 €');
    expect(normal(formaterMontant(12))).toBe('12,00 €');
  });

  it('montant à quatre décimales (tarif Minos) : jamais arrondi à deux décimales', () => {
    expect(normal(formaterMontant(0.1235))).toBe('0,1235 €');
    expect(normal(formaterMontant(1.2345))).toBe('1,2345 €');
    expect(normal(formaterMontant(0.875))).toBe('0,875 €');
    expect(normal(formaterMontant(3.5))).toBe('3,50 €');
  });

  it('montant absent ou non fini : « — »', () => {
    expect(formaterMontant(null)).toBe('—');
    expect(formaterMontant(undefined)).toBe('—');
    expect(formaterMontant(Number.NaN)).toBe('—');
  });

  it('nombre entier lisible, « — » si absent', () => {
    expect(normal(formaterNombre(1234))).toBe('1 234');
    expect(formaterNombre(0)).toBe('0');
    expect(formaterNombre(null)).toBe('—');
    expect(formaterNombre(undefined)).toBe('—');
  });

  it('période de promotion', () => {
    expect(periodePromo('2026-11-01T00:00:00.000Z', '2026-11-30T00:00:00.000Z')).toMatch(/^1 nov\.? 2026 au 30 nov\.? 2026$/);
    expect(periodePromo('2026-11-01T00:00:00.000Z', null)).toMatch(/^Depuis le 1 nov\.? 2026$/);
    expect(periodePromo(null, '2026-11-30T00:00:00.000Z')).toMatch(/^Jusqu'au 30 nov\.? 2026$/);
    expect(periodePromo(null, null)).toBe('—');
    expect(periodePromo('pas une date', undefined)).toBe('—');
  });
});

describe('hrefProduit', () => {
  it('adresse de la fiche', () => {
    expect(hrefProduit(FIL.id)).toBe(`/produits/${FIL.id}`);
  });

  it('l’identifiant est encodé : il ne peut pas sortir du segment', () => {
    expect(hrefProduit('../admin')).toBe('/produits/..%2Fadmin');
    expect(hrefProduit('a?b#c')).toBe('/produits/a%3Fb%23c');
  });
});

describe('lignesInformations', () => {
  it('fiche de la demande : libellés et valeurs, dans l’ordre', () => {
    expect(lignesInformations(FIL).map((l) => [l.label, l.valeur])).toEqual([
      ['Libellé', 'AC-FIL POLY 200M ROSE'],
      ['ID-AS400', '20738'],
      ['Famille', 'TEXTILE'],
      ['Gencode', '3666085207382'],
      ['Type article', 'Textile'],
      ['TVA', 'Taux normal'],
      ['Famille Plan', 'ATELIER C&C'],
      ['Gamme', 'MERCERIE'],
      ['Marque', 'ATELIER C&C'],
      ['Famille ACD', 'FIL MERCERIE'],
      ['Sous famille ACD', 'non définie'],
      ['Statut', 'TEXT'],
      ['Sous statut', 'ACTIF'],
      ['Retour autorisé', 'Non'],
      ['PCB', '12'],
    ]);
  });

  it('retour autorisé : Oui', () => {
    expect(lignesInformations({ ...FIL, retourAutorise: true }).find((l) => l.label === 'Retour autorisé')?.valeur).toBe('Oui');
  });

  it('valeurs vides : « — », sauf familles ACD (« non définie »)', () => {
    const vide: ArticleDetail = {
      ...FIL,
      gencode: null,
      typeArticle: null,
      codeTva: null,
      famillePlan: '  ',
      familleAcd: null,
      sousFamilleAcd: '',
      statut: null,
      sousStatut: null,
      pcb: null,
      marque: null,
      gamme: null,
      famille: null,
    };
    const valeurs = Object.fromEntries(lignesInformations(vide).map((l) => [l.label, l.valeur]));
    expect(valeurs).toMatchObject({
      Famille: '—',
      Gencode: '—',
      'Type article': '—',
      TVA: '—',
      'Famille Plan': '—',
      Gamme: '—',
      Marque: '—',
      'Famille ACD': 'non définie',
      'Sous famille ACD': 'non définie',
      Statut: '—',
      'Sous statut': '—',
      PCB: '—',
    });
  });

  it('TVA : code d’import à un seul caractère, ou code inconnu', () => {
    const tva = (codeTva: string | null) => lignesInformations({ ...FIL, codeTva }).find((l) => l.label === 'TVA')?.valeur;
    expect(tva('1')).toBe('Taux normal');
    expect(tva('2')).toBe('Code 2');
  });

  it('codes en police à chasse fixe, libellé sur toute la largeur', () => {
    const lignes = lignesInformations(FIL);
    expect(lignes.filter((l) => l.mono).map((l) => l.label)).toEqual(['ID-AS400', 'Gencode']);
    expect(lignes.filter((l) => l.large).map((l) => l.label)).toEqual(['Libellé']);
  });
});
