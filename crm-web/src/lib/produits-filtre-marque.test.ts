import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';

// Le sélecteur lit l'adresse et la réécrit : routeur et paramètres sont remplacés par des coquilles.
vi.mock('next/navigation', () => ({
  useRouter: () => ({ replace: () => undefined }),
  usePathname: () => '/produits',
  useSearchParams: () => new URLSearchParams(),
}));
const { ProduitsFiltreMarque } = await import('@/components/produits-filtre-marque');

const A = '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50';
const B = '8a1d6c20-1b3e-4f7a-8c9d-2e4f6a8b0c1d';
const MARQUES = [
  { id: A, nom: 'ABC Cosmétique', nbArticles: 15 },
  { id: B, nom: 'DermaSoft', nbArticles: 10 },
];

describe('sélecteur de marque', () => {
  it('« Toutes les marques » puis chaque marque avec son nombre d’articles, étiquette accessible', () => {
    const html = renderToStaticMarkup(createElement(ProduitsFiltreMarque, { marques: MARQUES }));
    expect(html).toContain('Toutes les marques');
    expect(html).toContain('ABC Cosmétique (15)');
    expect(html).toContain('DermaSoft (10)');
    expect(html).toContain('for="produits-marque"');
    expect(html).toContain('id="produits-marque"');
  });

  it('la marque de l’adresse est présélectionnée', () => {
    const html = renderToStaticMarkup(createElement(ProduitsFiltreMarque, { marques: MARQUES, marque: B }));
    expect(html).toMatch(new RegExp(`<option value="${B}" selected`));
  });
});
