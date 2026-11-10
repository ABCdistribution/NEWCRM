import { describe, expect, it } from 'vitest';

describe('garde-fou « aucun réseau » (src/test/sans-reseau.ts)', () => {
  it('fetch lève au lieu de contacter une API', () => {
    expect(() => fetch('http://localhost:4000/me')).toThrow(/Réseau interdit dans les tests/);
  });

  it('le garde-fou vaut aussi pour une adresse distante', () => {
    expect(() => fetch('https://exemple.invalid/')).toThrow(/Réseau interdit dans les tests/);
  });
});
