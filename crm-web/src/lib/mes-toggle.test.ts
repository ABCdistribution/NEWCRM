import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';

let adresse = '';
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: () => undefined }),
  usePathname: () => '/commandes',
  useSearchParams: () => new URLSearchParams(adresse),
}));
const { MesToggle } = await import('@/components/mes-toggle');

describe('bascule « Mes commandes » / « Mes visites »', () => {
  it('cochée par défaut (sans tous=1)', () => {
    adresse = '';
    const html = renderToStaticMarkup(createElement(MesToggle, { libelle: 'Mes commandes' }));
    expect(html).toContain('Mes commandes');
    expect(html).toContain('checked=""');
  });

  it('décochée quand l’adresse porte tous=1', () => {
    adresse = 'tous=1&search=abc';
    const html = renderToStaticMarkup(createElement(MesToggle, { libelle: 'Mes visites' }));
    expect(html).toContain('Mes visites');
    expect(html).not.toContain('checked=""');
  });
});
