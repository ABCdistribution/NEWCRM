import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { barresEan13 } from '@/lib/ean13';
import { modulesCode128 } from '@/lib/code128';
import { barresDeModules } from '@/lib/barres';
import { CodeBarres } from './code-barres';

const rendre = (gencode: string | null | undefined) => renderToStaticMarkup(createElement(CodeBarres, { gencode }));

describe('CodeBarres : EAN-13', () => {
  it('EAN-13 valide : SVG en ligne accessible, barres noires sur fond blanc, treize chiffres dessous', () => {
    const html = rendre('3666085207382');
    expect(html).toContain('<svg');
    expect(html).toContain('role="img"');
    expect(html).toContain('aria-label="Code-barres EAN-13 3666085207382"');
    expect(html).toContain('class="fill-white"'); // fond blanc (zones de silence comprises)
    expect(html).toContain('fill-black');
    const chiffres = [...html.matchAll(/<text[^>]*>(\d)<\/text>/g)].map((m) => m[1]).join('');
    expect(chiffres).toBe('3666085207382');
  });

  it('une barre par groupe de modules noirs, plus le fond ; zones de silence de 11 et 7 modules', () => {
    const html = rendre('3666085207382');
    const barres = barresEan13('3666085207382')!;
    expect([...html.matchAll(/<rect /g)]).toHaveLength(barres.length + 1);
    expect(html).toContain('viewBox="0 0 113 56"'); // 11 + 95 + 7 modules
    const xs = [...html.matchAll(/<rect x="(\d+)" y="2"/g)].map((m) => Number(m[1]));
    expect(Math.min(...xs)).toBe(11); // première barre après la zone de silence de gauche
    const dernier = barres[barres.length - 1];
    expect(Math.max(...xs) + dernier.largeur).toBe(11 + 95); // 7 modules libres restent à droite
  });

  it('les gardes (début, centre, fin) descendent plus bas que les barres des chiffres', () => {
    const html = rendre('5901234123457');
    const hauteurs = [...html.matchAll(/<rect x="\d+" y="2" width="\d+" height="(\d+)"/g)].map((m) => Number(m[1]));
    expect(hauteurs.filter((h) => h === 52)).toHaveLength(6); // 2 barres par garde, 3 gardes
    expect(hauteurs.filter((h) => h === 44).length).toBeGreaterThan(0);
  });

  it('UPC-A valide : dessiné en EAN-13 avec le 0 initial', () => {
    const html = rendre('036000291452');
    expect(html).toContain('aria-label="Code-barres EAN-13 0036000291452"');
    const chiffres = [...html.matchAll(/<text[^>]*>(\d)<\/text>/g)].map((m) => m[1]).join('');
    expect(chiffres).toBe('0036000291452');
  });
});

describe('CodeBarres : EAN-8', () => {
  it('EAN-8 valide : 67 modules, 8 chiffres dessous, gardes plus longues', () => {
    const html = rendre('96385074');
    expect(html).toContain('aria-label="Code-barres EAN-8 96385074"');
    expect(html).toContain('viewBox="0 0 81 56"'); // 7 + 67 + 7 modules
    const chiffres = [...html.matchAll(/<text[^>]*>(\d)<\/text>/g)].map((m) => m[1]).join('');
    expect(chiffres).toBe('96385074');
    const hauteurs = [...html.matchAll(/<rect x="\d+" y="2" width="\d+" height="(\d+)"/g)].map((m) => Number(m[1]));
    expect(hauteurs.filter((h) => h === 52)).toHaveLength(6);
  });
});

describe('CodeBarres : Code 128 pour tout autre gencode', () => {
  it.each([
    ['clé de contrôle fausse', '3666085207383'],
    ['12 chiffres dont la clé UPC-A est fausse', '376123450031'],
    ['14 chiffres', '36660852073821'],
    ['lettres', 'ABC123'],
  ])('%s : un code-barres est dessiné et il encode exactement le numéro', (_libelle, gencode) => {
    const html = rendre(gencode);
    expect(html).toContain('<svg');
    expect(html).toContain('role="img"');
    expect(html).toContain(`aria-label="Code-barres Code 128 ${gencode}"`);
    expect(html).toContain(`>${gencode}</text>`); // le numéro est écrit sous les barres
    // Les barres dessinées sont exactement celles du symbole Code 128 de ce numéro.
    const attendues = barresDeModules(modulesCode128(gencode)!);
    const dessinees = [...html.matchAll(/<rect x="(\d+)" y="2" width="(\d+)" height="44"/g)].map((m) => ({
      x: Number(m[1]) - 10, // zone de silence de 10 modules
      largeur: Number(m[2]),
    }));
    expect(dessinees).toEqual(attendues);
  });

  it('zones de silence de 10 modules de chaque côté, aucune garde plus longue', () => {
    const gencode = '376123450031';
    const html = rendre(gencode);
    const modules = modulesCode128(gencode)!.length;
    expect(html).toContain(`viewBox="0 0 ${10 + modules + 10} 56"`);
    const hauteurs = [...html.matchAll(/<rect x="\d+" y="2" width="\d+" height="(\d+)"/g)].map((m) => Number(m[1]));
    expect(hauteurs.every((h) => h === 44)).toBe(true);
  });
});

describe('CodeBarres : rendu', () => {
  it('pas de crispEdges : à une échelle non entière, il déformerait les proportions des barres', () => {
    for (const gencode of ['3666085207382', '376123450031']) {
      expect(rendre(gencode)).not.toContain('shape-rendering');
    }
  });

  it('aucune couleur en dur : barres et fond passent par les classes noir / blanc', () => {
    for (const gencode of ['3666085207382', '96385074', '376123450031']) {
      const html = rendre(gencode);
      expect(html).not.toMatch(/#[0-9a-f]{3,8}\b/i);
      expect(html).not.toMatch(/fill="/);
    }
  });

  it.each([
    ['accent', 'é1'],
    ['trop long (plus de 32 caractères)', 'A'.repeat(33)],
    ['retour à la ligne', '12\n34'],
  ])('%s : pas de dessin, seulement le texte', (_libelle, gencode) => {
    const html = rendre(gencode);
    expect(html).not.toContain('<svg');
    expect(html).not.toContain('role="img"');
  });

  it.each([null, undefined, '', '   '])('gencode absent (%j) : « — », jamais de dessin', (gencode) => {
    const html = rendre(gencode);
    expect(html).not.toContain('<svg');
    expect(html).toContain('—');
  });
});
