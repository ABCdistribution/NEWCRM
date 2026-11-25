import { describe, expect, it } from 'vitest';
import { MAX_CARACTERES_CODE128, MOTIFS_CODE128, cleCode128, modulesCode128, valeursCode128 } from './code128';

/**
 * Valeurs de référence produites par une bibliothèque indépendante (JsBarcode 3.11.6, rendu « object »), recopiées ici :
 * elles ne dépendent donc pas de l'implémentation testée.
 */
const REFERENCE: [texte: string, modules: string][] = [
  ['12345678', '1101001110010110011100100010110001110001011011000010100100011101101100011101011'],
  ['376123450030', '11010011100100011010001100100001011101101110101110110001101100110011011011000110000100101100011101011'],
  ['12', '1101001110010110011100100110011101100011101011'],
  ['ABC123', '11010010000101000110001000101100010001000110100111001101100111001011001011100100001011001100011101011'],
  [
    'Hello world!',
    '11010010000110001010001011001000011001010000110010100001000111101011011001100111100101001000111101010010011110110010100001000010011011001101100100001101001100011101011',
  ],
  ['5', '1101001000011011100100110011101001100011101011'],
  [
    '3666085207383', // nombre impair de chiffres : paires en C puis dernier chiffre après bascule en A
    '110100111001011000100010010000110100011001001101110001010011000100100011000101110101111011001011100100100111101100011101011',
  ],
  ['123', '11010011100101100111001110101111011001011100100001011001100011101011'],
];

/** Décodeur indépendant : retrouve la chaîne à partir des modules (vérifie départ, clé de contrôle et arrêt). */
function decoder(modules: string): string {
  const symboles: number[] = [];
  let reste = modules;
  while (reste.length > 13) {
    const bloc = reste.slice(0, 11);
    const valeur = MOTIFS_CODE128.slice(0, 106).findIndex((m) => expand(m) === bloc);
    expect(valeur).toBeGreaterThanOrEqual(0);
    symboles.push(valeur);
    reste = reste.slice(11);
  }
  expect(reste).toBe(expand(MOTIFS_CODE128[106])); // arrêt
  const cle = symboles.pop()!;
  let somme = symboles[0];
  for (let i = 1; i < symboles.length; i++) somme += i * symboles[i];
  expect(somme % 103).toBe(cle);

  let jeu: 'B' | 'C' = symboles[0] === 105 ? 'C' : 'B';
  expect([104, 105]).toContain(symboles[0]);
  let texte = '';
  for (const v of symboles.slice(1)) {
    if (v === 100 || v === 101) jeu = 'B'; // bascule en B ou en A : mêmes valeurs pour les caractères utilisés ici
    else if (v === 99) jeu = 'C';
    else texte += jeu === 'C' ? String(v).padStart(2, '0') : String.fromCharCode(v + 32);
  }
  return texte;
}

function expand(motif: string): string {
  let noir = true;
  let s = '';
  for (const l of motif) {
    s += (noir ? '1' : '0').repeat(Number(l));
    noir = !noir;
  }
  return s;
}

describe('table des symboles Code 128', () => {
  it('107 motifs : 106 symboles de 11 modules et l\'arrêt de 13', () => {
    expect(MOTIFS_CODE128).toHaveLength(107);
    for (const [valeur, motif] of MOTIFS_CODE128.entries()) {
      const somme = [...motif].reduce((n, c) => n + Number(c), 0);
      expect(somme, `symbole ${valeur}`).toBe(valeur === 106 ? 13 : 11);
      expect(motif).toHaveLength(valeur === 106 ? 7 : 6);
    }
  });

  it('motifs tous différents, éléments de 1 à 4 modules', () => {
    expect(new Set(MOTIFS_CODE128).size).toBe(107);
    for (const motif of MOTIFS_CODE128) for (const c of motif) expect(Number(c)).toBeGreaterThanOrEqual(1);
    for (const motif of MOTIFS_CODE128) for (const c of motif) expect(Number(c)).toBeLessThanOrEqual(4);
  });
});

describe('modulesCode128', () => {
  it.each(REFERENCE)('« %s » : identique à la bibliothèque de référence', (texte, modules) => {
    expect(modulesCode128(texte)).toBe(modules);
  });

  it.each(REFERENCE.map(([t]) => t))('« %s » : le décodage redonne exactement la chaîne', (texte) => {
    expect(decoder(modulesCode128(texte)!)).toBe(texte);
  });

  it('chiffres seuls en jeu C (départ 105), nombre impair : C puis bascule en A', () => {
    expect(valeursCode128('1234')).toEqual([105, 12, 34]);
    expect(valeursCode128('123')).toEqual([105, 12, 101, 19]); // « 3 » = 0x33 - 32 = 19
    expect(valeursCode128('7')).toEqual([104, 23]);
    expect(valeursCode128('AB')).toEqual([104, 33, 34]);
  });

  it('clé de contrôle : exemple calculé à la main (105 + 12 + 2×34 + 3×56 + 4×78 = 665, 665 mod 103 = 47)', () => {
    expect(cleCode128([105, 12, 34, 56, 78])).toBe(47);
  });

  it('commence par le motif de départ et finit par l\'arrêt (13 modules)', () => {
    const modules = modulesCode128('3761234500')!;
    expect(modules.startsWith(expand(MOTIFS_CODE128[105]))).toBe(true);
    expect(modules.endsWith(expand(MOTIFS_CODE128[106]))).toBe(true);
    expect(modules).toHaveLength(11 * (1 + 5 + 1) + 13);
  });

  it.each([
    ['vide', ''],
    ['null', null],
    ['undefined', undefined],
    ['accent', 'été'],
    ['retour à la ligne', '12\n34'],
    ['tabulation', '12\t34'],
    ['chiffres non ASCII', '３６６６'],
    ['trop long', 'A'.repeat(MAX_CARACTERES_CODE128 + 1)],
  ])('refuse : %s (pas de dessin)', (_libelle, valeur) => {
    expect(modulesCode128(valeur as string | null | undefined)).toBeNull();
  });

  it('accepte la longueur maximale', () => {
    expect(modulesCode128('A'.repeat(MAX_CARACTERES_CODE128))).not.toBeNull();
  });
});
