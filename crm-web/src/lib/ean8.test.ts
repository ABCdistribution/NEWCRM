import { describe, expect, it } from 'vitest';
import { GARDES_EAN8, MODULES_EAN8, cleEan8, estEan8, modulesEan8 } from './ean8';

describe('cleEan8', () => {
  it.each([
    ['9638507', 4], // exemple de référence : 96385074
    ['5512345', 7], // 55123457
    ['0000000', 0],
  ])('%s -> %i', (sept, cle) => {
    expect(cleEan8(sept)).toBe(cle);
  });

  it.each(['', '123456', '12345678', 'abcdefg', '963850 '])('refuse « %s » (pas sept chiffres)', (v) => {
    expect(cleEan8(v)).toBeNull();
  });
});

describe('estEan8', () => {
  it.each(['96385074', '55123457', '00000000'])('%s est valide', (code) => {
    expect(estEan8(code)).toBe(true);
  });

  it.each(['96385075', '9638507', '963850744', 'ABCDEFGH', '9638 5074', ''])('« %s » est refusé', (code) => {
    expect(estEan8(code)).toBe(false);
  });

  it('refuse null et undefined', () => {
    expect(estEan8(null)).toBe(false);
    expect(estEan8(undefined)).toBe(false);
  });
});

describe('modulesEan8', () => {
  it('96385074 : symbole identique à la bibliothèque de référence (JsBarcode 3.11.6)', () => {
    expect(modulesEan8('96385074')).toBe('1010001011010111101111010110111010101001110111001010001001011100101');
  });

  it('67 modules, gardes aux bons endroits', () => {
    for (const code of ['96385074', '55123457', '00000000']) {
      const modules = modulesEan8(code)!;
      expect(modules).toHaveLength(MODULES_EAN8);
      for (const { x, largeur } of GARDES_EAN8) {
        expect(modules.slice(x, x + largeur)).toBe(largeur === 5 ? '01010' : '101');
      }
    }
  });

  it('null pour un code invalide', () => {
    expect(modulesEan8('96385075')).toBeNull();
    expect(modulesEan8(null)).toBeNull();
  });
});
