import { describe, expect, it } from 'vitest';
import { symboleCodeBarres } from './code-barres';
import { modulesCode128 } from './code128';
import { modulesEan13 } from './ean13';

describe('symboleCodeBarres : choix du symbole', () => {
  it('EAN-13 valide : EAN-13', () => {
    const s = symboleCodeBarres('3666085207382')!;
    expect(s.type).toBe('EAN-13');
    expect(s.texte).toBe('3666085207382');
    expect(s.modules).toBe(modulesEan13('3666085207382'));
  });

  it('UPC-A valide (12 chiffres) : dessiné comme l\'EAN-13 qui commence par 0', () => {
    const s = symboleCodeBarres('036000291452')!;
    expect(s.type).toBe('EAN-13');
    expect(s.texte).toBe('0036000291452');
    // symbole identique à la bibliothèque de référence (JsBarcode 3.11.6, EAN13 0036000291452)
    expect(s.modules).toBe('10100011010111101010111100011010001101000110101010110110011101001100110101110010011101101100101');
  });

  it('EAN-8 valide : EAN-8', () => {
    const s = symboleCodeBarres('96385074')!;
    expect(s.type).toBe('EAN-8');
    expect(s.texte).toBe('96385074');
  });

  it.each([
    ['12 chiffres dont la clé UPC-A est fausse', '376123450031'],
    ['13 chiffres, clé de contrôle fausse', '3666085207383'],
    ['14 chiffres', '36660852073821'],
    ['EAN-8 à clé fausse', '96385075'],
    ['lettres', 'ABC123'],
    ['avec espaces internes', '3666 0852 0738 2'],
  ])('%s : Code 128 qui encode exactement le texte', (_libelle, gencode) => {
    const s = symboleCodeBarres(gencode)!;
    expect(s.type).toBe('Code 128');
    expect(s.texte).toBe(gencode);
    expect(s.modules).toBe(modulesCode128(gencode));
  });

  it('espaces autour du gencode ignorés', () => {
    expect(symboleCodeBarres(' 3666085207382 ')!.texte).toBe('3666085207382');
  });

  it.each([null, undefined, '', '   ', 'é', '12\n34', 'A'.repeat(33)])('%j : pas de symbole', (gencode) => {
    expect(symboleCodeBarres(gencode)).toBeNull();
  });
});
