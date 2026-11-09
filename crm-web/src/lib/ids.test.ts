import { beforeEach, describe, expect, it, vi } from 'vitest';
import { idSur } from './api';
import { estUuid } from './equipe-utils';

// `notFound` est remplacé comme le fait Next : il ne rend jamais la main (il lève une erreur spéciale).
// `next/headers` est neutralisé : valider un id ne lit jamais la session (aucun cookie, aucun réseau).
const mocks = vi.hoisted(() => ({ notFound: vi.fn() }));
vi.mock('next/navigation', () => ({ notFound: mocks.notFound }));
vi.mock('next/headers', () => ({ cookies: vi.fn() }));

const ID = '123e4567-e89b-42d3-a456-426614174000';

/** Valeur volontairement hors du contrat de type (paramètre d'URL absent ou mal formé). */
const horsContrat = (valeur: unknown): string => valeur as string;

const VALIDES = [
  { libelle: 'UUID en minuscules', valeur: ID },
  { libelle: 'UUID en majuscules', valeur: ID.toUpperCase() },
  { libelle: 'casse mélangée', valeur: '123E4567-e89b-42D3-A456-426614174000' },
  { libelle: 'UUID nul (seule la forme est contrôlée : l\'API reste juge)', valeur: '00000000-0000-0000-0000-000000000000' },
  { libelle: 'UUID horodaté (v7)', valeur: '018f3a52-7c1e-7a3b-9f4d-0e8b2a6c1d90' },
];

const INVALIDES = [
  { libelle: 'chaîne vide', valeur: '' },
  { libelle: 'un mot', valeur: 'abc' },
  { libelle: 'un entier', valeur: '12345' },
  { libelle: 'traversée de répertoire', valeur: '../../etc/passwd' },
  { libelle: 'traversée encodée', valeur: '..%2f..%2fadmin' },
  { libelle: 'UUID suivi d\'un sous-chemin', valeur: `${ID}/../users` },
  { libelle: 'UUID suivi d\'une requête', valeur: `${ID}?admin=1` },
  { libelle: 'UUID suivi d\'une ancre', valeur: `${ID}#x` },
  { libelle: 'UUID suivi d\'un saut de ligne', valeur: `${ID}\n` },
  { libelle: 'UUID suivi d\'un espace', valeur: `${ID} ` },
  { libelle: 'UUID précédé d\'un espace', valeur: ` ${ID}` },
  { libelle: 'UUID suivi d\'un octet nul', valeur: `${ID}\u0000` },
  { libelle: 'UUID entre accolades', valeur: `{${ID}}` },
  { libelle: 'préfixe urn:uuid:', valeur: `urn:uuid:${ID}` },
  { libelle: 'sans tirets', valeur: ID.replaceAll('-', '') },
  { libelle: '35 caractères (un de moins)', valeur: ID.slice(0, -1) },
  { libelle: '37 caractères (un de plus)', valeur: `${ID}0` },
  { libelle: 'caractère non hexadécimal (g)', valeur: ID.replace('1', 'g') },
  { libelle: 'chiffres pleine chasse (non ASCII)', valeur: ID.replace('123', '１２３') },
  { libelle: 'deux UUID collés', valeur: `${ID}${ID}` },
  { libelle: 'deux UUID séparés par une virgule', valeur: `${ID},${ID}` },
];

beforeEach(() => {
  mocks.notFound.mockReset();
  mocks.notFound.mockImplementation(() => {
    throw new Error('NEXT_NOT_FOUND');
  });
});

describe('idSur (identifiant inséré dans un chemin d\'API)', () => {
  it.each(VALIDES)('$libelle : renvoyé tel quel, sans 404', ({ valeur }) => {
    expect(idSur(valeur)).toBe(valeur);
    expect(mocks.notFound).not.toHaveBeenCalled();
  });

  it.each(INVALIDES)('$libelle : 404 (notFound), l\'id n\'atteint jamais le chemin d\'API', ({ valeur }) => {
    expect(() => idSur(valeur)).toThrow('NEXT_NOT_FOUND');
    expect(mocks.notFound).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['undefined', undefined],
    ['null', null],
  ])('paramètre manquant (%s) : 404, pas de TypeError', (_libelle, valeur) => {
    expect(() => idSur(horsContrat(valeur))).toThrow('NEXT_NOT_FOUND');
    expect(mocks.notFound).toHaveBeenCalledTimes(1);
  });

  it('ne modifie pas l\'identifiant valide (ni casse, ni espaces)', () => {
    expect(idSur(ID.toUpperCase())).toBe(ID.toUpperCase());
  });
});

describe('estUuid (garde des pages et des Server Actions de l\'équipe)', () => {
  it.each(VALIDES)('$libelle : vrai', ({ valeur }) => {
    expect(estUuid(valeur)).toBe(true);
  });

  it.each(INVALIDES)('$libelle : faux', ({ valeur }) => {
    expect(estUuid(valeur)).toBe(false);
  });

  it.each([
    ['undefined', undefined],
    ['null', null],
  ])('paramètre manquant (%s) : faux, sans lever', (_libelle, valeur) => {
    expect(estUuid(horsContrat(valeur))).toBe(false);
  });

  it('même grammaire que idSur : mêmes valeurs acceptées, mêmes valeurs refusées', () => {
    for (const { libelle, valeur } of [...VALIDES, ...INVALIDES]) {
      let accepteParIdSur = true;
      try {
        idSur(valeur);
      } catch {
        accepteParIdSur = false;
      }
      expect(estUuid(valeur), libelle).toBe(accepteParIdSur);
    }
  });
});
