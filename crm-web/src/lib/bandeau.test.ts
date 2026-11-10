import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';

// Le bandeau n'exécute ici ni routeur, ni Server Action : tout est remplacé par des coquilles.
vi.mock('next/navigation', () => ({ useRouter: () => ({ push: () => undefined }) }));
vi.mock('./recherche-actions', () => ({ rechercherGlobal: async () => ({ data: { q: '', groupes: [] } }) }));
vi.mock('./auth-actions', () => ({ logout: async () => undefined }));
vi.mock('./notification-actions', () => ({ marquerLu: async () => ({}), marquerToutLu: async () => ({}) }));
const { Bandeau } = await import('@/components/bandeau');

const ME = { id: '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50', displayName: 'Adrien RICHARD', poste: 'Directeur régional', role: 'DIRECTEUR_REGIONAL' as const };
const nbsp = (s: string) => s.replace(/[  ]/g, ' ');

describe('bandeau du haut : activité de l’utilisateur', () => {
  it('sous son nom : visites, commandes, CA et objectif du mois', () => {
    const html = nbsp(
      renderToStaticMarkup(
        createElement(Bandeau, { me: ME, notifications: null, activite: { visites: 0, commandes: 0, ca: 0, objectif: null, tauxPct: null } }),
      ),
    );
    expect(html).toContain('Adrien RICHARD');
    expect(html).toContain('Directeur régional');
    expect(html).toContain('0 visite · 0 commande · CA 0 € · objectif non défini');
    expect(html).toContain('aria-label="Mon activité du mois : 0 visite, 0 commande, CA 0 €, objectif non défini"');
  });

  it('avec un objectif : le pourcentage est écrit et la ligne prend la teinte de l’atteinte', () => {
    const html = nbsp(
      renderToStaticMarkup(
        createElement(Bandeau, { me: ME, notifications: null, activite: { visites: 3, commandes: 2, ca: 8000, objectif: 10000, tauxPct: 80 } }),
      ),
    );
    expect(html).toContain('3 visites · 2 commandes · CA 8 000 € · objectif 10 000 € (80 %)');
    expect(html).toContain('text-amber-800');
  });

  it('sans activité (autres rôles) : aucune ligne d’activité', () => {
    const html = renderToStaticMarkup(createElement(Bandeau, { me: { ...ME, role: 'ADMIN' as const }, notifications: null }));
    expect(html).not.toContain('Mon activité du mois');
  });
});
