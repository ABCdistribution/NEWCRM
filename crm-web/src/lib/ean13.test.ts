import { describe, expect, it } from 'vitest';
import { GARDES_EAN13, MODULES_EAN13, barresEan13, cleEan13, estEan13, modulesEan13 } from './ean13';

/**
 * Symboles écrits à la main d'après la norme (jeux L, G et R), indépendamment de l'implémentation :
 * garde 101 + 6 chiffres de gauche + 01010 + 6 chiffres de droite + garde 101.
 */
const ATTENDUS: [code: string, modules: string][] = [
  [
    '5901234123457', // exemple de référence (premier chiffre 5 : LGGLLG)
    '101' + '0001011' + '0100111' + '0110011' + '0010011' + '0111101' + '0011101' + '01010' +
      '1100110' + '1101100' + '1000010' + '1011100' + '1001110' + '1000100' + '101',
  ],
  [
    '3666085207382', // fil à coudre de la fiche produit (premier chiffre 3 : LLGGGL)
    '101' + '0101111' + '0101111' + '0000101' + '0100111' + '0001001' + '0110001' + '01010' +
      '1101100' + '1110010' + '1000100' + '1000010' + '1001000' + '1101100' + '101',
  ],
];

describe('cleEan13 (clé de contrôle)', () => {
  it.each([
    ['590123412345', 7],
    ['366608520738', 2],
    ['400638133393', 1],
    ['000000000000', 0],
    ['978020137962', 4], // ISBN 978-0-201-37962-4 (préfixe 978 des livres)
  ])('%s -> %i', (douze, cle) => {
    expect(cleEan13(douze)).toBe(cle);
  });

  it.each(['', '12345678901', '1234567890123', 'abcdefghijkl', '59012341234 ', ' 590123412345'])(
    'refuse « %s » (pas douze chiffres)',
    (valeur) => {
      expect(cleEan13(valeur)).toBeNull();
    },
  );
});

describe('estEan13', () => {
  it.each(['3666085207382', '5901234123457', '4006381333931', '9780201379624', '0000000000000'])('%s est valide', (code) => {
    expect(estEan13(code)).toBe(true);
  });

  it('refuse une clé de contrôle fausse, quel que soit le chiffre changé', () => {
    expect(estEan13('3666085207383')).toBe(false); // clé
    expect(estEan13('3666085207392')).toBe(false); // un chiffre du corps
    expect(estEan13('4666085207382')).toBe(false); // premier chiffre
  });

  it.each([
    ['trop court (12 chiffres)', '366608520738'],
    ['trop long (14 chiffres)', '36660852073821'],
    ['vide', ''],
    ['lettres', '36660852073AB'],
    ['espace final', '3666085207382 '],
    ['espaces internes', '3666 0852 0738 2'],
    ['tirets', '3-666085-207382'],
    ['chiffres non ASCII', '３６６６０８５２０７３８２'],
    ['retour à la ligne', '3666085207382\n'],
  ])('refuse : %s', (_libelle, code) => {
    expect(estEan13(code)).toBe(false);
  });

  it('refuse null, undefined et un nombre', () => {
    expect(estEan13(null)).toBe(false);
    expect(estEan13(undefined)).toBe(false);
    expect(estEan13(3666085207382 as unknown as string)).toBe(false);
  });
});

describe('modulesEan13', () => {
  it.each(ATTENDUS)('%s : symbole conforme à la norme', (code, modules) => {
    expect(modulesEan13(code)).toBe(modules);
  });

  it('95 modules, gardes aux bons endroits, pour une série de codes valides', () => {
    for (const code of ['3666085207382', '5901234123457', '4006381333931', '9780201379624', '0000000000000']) {
      const modules = modulesEan13(code);
      expect(modules).toHaveLength(MODULES_EAN13);
      expect(modules).toMatch(/^[01]+$/);
      expect(modules!.slice(0, 3)).toBe('101');
      expect(modules!.slice(45, 50)).toBe('01010');
      expect(modules!.slice(92)).toBe('101');
    }
  });

  it('chaque chiffre de gauche commence par 0 et finit par 1, chaque chiffre de droite commence par 1 et finit par 0', () => {
    const modules = modulesEan13('3666085207382')!;
    for (let i = 0; i < 6; i++) {
      const gauche = modules.slice(3 + i * 7, 3 + (i + 1) * 7);
      expect(gauche[0] + gauche[6]).toBe('01');
      const droite = modules.slice(50 + i * 7, 50 + (i + 1) * 7);
      expect(droite[0] + droite[6]).toBe('10');
    }
  });

  it('renvoie null pour une clé fausse, une mauvaise longueur ou une valeur absente (jamais un dessin faux)', () => {
    expect(modulesEan13('3666085207383')).toBeNull();
    expect(modulesEan13('366608520738')).toBeNull();
    expect(modulesEan13('36660852073821')).toBeNull();
    expect(modulesEan13('')).toBeNull();
    expect(modulesEan13(null)).toBeNull();
    expect(modulesEan13(undefined)).toBeNull();
  });
});

describe('barresEan13', () => {
  it('fusionne les modules noirs consécutifs ; les barres reconstituent exactement le symbole', () => {
    for (const code of ['3666085207382', '5901234123457', '4006381333931']) {
      const modules = modulesEan13(code)!;
      const barres = barresEan13(code)!;
      const reconstitue = Array.from({ length: MODULES_EAN13 }, () => '0');
      for (const { x, largeur } of barres) {
        expect(largeur).toBeGreaterThan(0);
        for (let i = x; i < x + largeur; i++) reconstitue[i] = '1';
      }
      expect(reconstitue.join('')).toBe(modules);
      // Deux barres voisines sont toujours séparées par au moins un module blanc.
      for (let i = 1; i < barres.length; i++) expect(barres[i].x).toBeGreaterThan(barres[i - 1].x + barres[i - 1].largeur);
    }
  });

  it('aucune barre plus large que quatre modules (limite de la norme)', () => {
    for (const code of ['3666085207382', '5901234123457', '0000000000000', '9780201379624']) {
      for (const { largeur } of barresEan13(code)!) expect(largeur).toBeLessThanOrEqual(4);
    }
  });

  it('null pour un code invalide', () => {
    expect(barresEan13('1234567890123')).toBeNull();
    expect(barresEan13(null)).toBeNull();
  });
});

describe('GARDES_EAN13', () => {
  it('correspondent à de vraies barres du symbole', () => {
    const modules = modulesEan13('3666085207382')!;
    for (const { x, largeur } of GARDES_EAN13) {
      const morceau = modules.slice(x, x + largeur);
      expect(morceau).toBe(largeur === 5 ? '01010' : '101');
    }
  });
});
