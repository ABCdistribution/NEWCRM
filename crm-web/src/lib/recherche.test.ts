import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { assainirRecherche, FAMILLES, lienResultat, lienTous, type RechercheGlobale as Donnees } from './recherche';

// Le rendu du composant n'exécute ni routeur ni Server Action : on les remplace par des coquilles vides.
vi.mock('next/navigation', () => ({ useRouter: () => ({ push: () => undefined }) }));
vi.mock('./recherche-actions', () => ({ rechercherGlobal: async () => ({ data: { q: '', groupes: [] } }) }));

const { RechercheGlobale } = await import('@/components/recherche-globale');

const ID = '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50';
const ID2 = '8a1d6c20-1b3e-4f7a-8c9d-2e4f6a8b0c1d';

describe('lecture défensive de la réponse de l’API', () => {
  it('garde les familles connues dans l’ordre fixe, avec leurs lignes', () => {
    const r = assainirRecherche(
      {
        groupes: [
          { type: 'produits', total: 1, items: [{ id: ID, titre: 'Mascara', detail: 'Marque · P001', recherche: 'P001' }] },
          { type: 'clients', total: 12, items: [{ id: ID2, titre: 'Auchan Rouen', detail: 'Rouen · 00123' }] },
        ],
      },
      'auchan',
    );
    expect(r.groupes.map((g) => g.type)).toEqual(['clients', 'produits']);
    expect(r.groupes[0]).toEqual({ type: 'clients', total: 12, items: [{ id: ID2, titre: 'Auchan Rouen', detail: 'Rouen · 00123' }] });
  });

  it('écarte les familles inconnues, les doublons, les ids qui ne sont pas des UUID et les lignes sans titre', () => {
    const r = assainirRecherche(
      {
        groupes: [
          { type: 'mots_de_passe', total: 1, items: [{ id: ID, titre: 'x' }] },
          { type: 'clients', total: 3, items: [{ id: '../admin', titre: 'Piège' }, { id: ID, titre: '' }, { id: ID, titre: 'Bon' }] },
          { type: 'clients', total: 1, items: [{ id: ID2, titre: 'Doublon de famille' }] },
        ],
      },
      'x',
    );
    expect(r.groupes).toHaveLength(1);
    expect(r.groupes[0].items.map((i) => i.titre)).toEqual(['Bon']);
  });

  it('ne garde que les champs attendus (rôle connu, client en UUID) et borne le total', () => {
    const r = assainirRecherche(
      { groupes: [{ type: 'collaborateurs', total: -4, items: [{ id: ID, titre: 'A', role: 'ROOT', clientId: 'x', secret: 'non' }] }] },
      'a',
    );
    expect(r.groupes[0].items[0]).toEqual({ id: ID, titre: 'A', detail: null });
    expect(r.groupes[0].total).toBe(1);
  });

  it('toute autre forme de réponse donne « aucun résultat »', () => {
    for (const brut of [null, undefined, 'texte', 42, {}, { groupes: 'x' }, { groupes: [null, 3, { type: 'clients' }] }]) {
      expect(assainirRecherche(brut, 'q').groupes).toEqual([]);
    }
  });

  it('au plus 10 lignes par famille', () => {
    const items = Array.from({ length: 30 }, (_, i) => ({ id: `3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f${String(i).padStart(2, '0')}`, titre: `L${i}` }));
    expect(assainirRecherche({ groupes: [{ type: 'clients', total: 30, items }] }, 'l').groupes[0].items).toHaveLength(10);
  });
});

describe('liens des résultats', () => {
  it('clients, commandes et prospects : leur fiche', () => {
    expect(lienResultat('clients', { id: ID, titre: 'x', detail: null }, 'COMMERCIAL')).toBe(`/clients/${ID}`);
    expect(lienResultat('commandes', { id: ID, titre: 'x', detail: null }, 'ADV')).toBe(`/commandes/${ID}`);
    expect(lienResultat('prospects', { id: ID, titre: 'x', detail: null }, 'DIRECTION')).toBe(`/prospects/${ID}`);
  });

  it('visites et produits : la liste filtrée sur le texte à retrouver, échappé', () => {
    expect(lienResultat('visites', { id: ID, titre: 'x', detail: null, recherche: 'Auchan & Cie' }, 'ADMIN')).toBe('/visites?search=Auchan%20%26%20Cie');
    expect(lienResultat('produits', { id: ID, titre: 'x', detail: null, recherche: 'P 001' }, 'ADMIN')).toBe('/produits?search=P%20001');
    expect(lienResultat('visites', { id: ID, titre: 'x', detail: null }, 'ADMIN')).toBeNull();
  });

  it('collaborateurs : la fiche seulement si le rôle a le droit de l’ouvrir (jamais pour DIRECTION)', () => {
    const promoteur = { id: ID, titre: 'P', detail: null, role: 'COMMERCIAL' as const };
    const chef = { id: ID, titre: 'C', detail: null, role: 'CHEF_SECTEUR' as const };
    const dr = { id: ID, titre: 'D', detail: null, role: 'DIRECTEUR_REGIONAL' as const };
    expect(lienResultat('collaborateurs', promoteur, 'CHEF_SECTEUR')).toBe(`/mon-equipe/promoteur/${ID}`);
    expect(lienResultat('collaborateurs', promoteur, 'DIRECTION')).toBeNull();
    expect(lienResultat('collaborateurs', chef, 'DIRECTEUR_REGIONAL')).toBe(`/mon-equipe/${ID}`);
    expect(lienResultat('collaborateurs', chef, 'CHEF_SECTEUR')).toBeNull();
    expect(lienResultat('collaborateurs', dr, 'ADMIN')).toBeNull();
  });

  it('« voir tous » : seulement pour les familles dont la page de liste filtre sur le texte', () => {
    expect(lienTous('clients', 'auchan rouen')).toBe('/clients?vue=portefeuille&search=auchan%20rouen');
    expect(lienTous('commandes', 'c1')).toBe('/commandes?search=c1');
    expect(lienTous('collaborateurs', 'a')).toBeNull();
    expect(lienTous('prospects', 'a')).toBeNull();
  });

  it('chaque famille a un titre', () => {
    expect(FAMILLES.map((f) => f.libelle)).toEqual(['Clients', 'Commandes', 'Visites', 'Collaborateurs', 'Prospects', 'Produits']);
  });
});

describe('rendu de la recherche générale', () => {
  const rendre = (props: { role?: 'ADMIN' | 'CHEF_SECTEUR' | 'DIRECTION'; resultatInitial?: Donnees | null; saisieInitiale?: string } = {}) =>
    renderToStaticMarkup(createElement(RechercheGlobale, { role: props.role ?? 'ADMIN', ...props }));

  it('champ accessible, panneau fermé au départ', () => {
    const html = rendre();
    expect(html).toContain('role="combobox"');
    expect(html).toContain('aria-expanded="false"');
    expect(html).toContain('Recherche générale');
    expect(html).not.toContain('role="listbox"');
  });

  const DONNEES: Donnees = {
    q: 'adrien',
    groupes: [
      { type: 'clients', total: 9, items: [{ id: ID, titre: 'Auchan Rouen', detail: 'Rouen · 00123' }] },
      {
        type: 'collaborateurs',
        total: 1,
        items: [{ id: ID2, titre: 'Adrien SANTAGUILIANA', detail: 'Chef de secteur · code 305', role: 'CHEF_SECTEUR' }],
      },
    ],
  };

  it('résultats groupés par famille, avec lien et « voir les N résultats »', () => {
    const html = rendre({ role: 'ADMIN', resultatInitial: DONNEES, saisieInitiale: 'adrien' });
    expect(html).toContain('role="listbox"');
    expect(html).toContain('aria-expanded="true"');
    expect(html).toContain('aria-label="Clients"');
    expect(html).toContain('aria-label="Collaborateurs"');
    expect(html).toContain(`href="/clients/${ID}"`);
    expect(html).toContain('Auchan Rouen');
    expect(html).toContain('Voir les 9 résultats');
    expect(html).toContain('href="/clients?vue=portefeuille&amp;search=adrien"');
    expect(html).toContain(`href="/mon-equipe/${ID2}"`);
  });

  it('un collaborateur sans fiche pour ce rôle reste affiché, sans lien', () => {
    const html = rendre({ role: 'CHEF_SECTEUR', resultatInitial: DONNEES, saisieInitiale: 'adrien' });
    expect(html).toContain('Adrien SANTAGUILIANA');
    expect(html).not.toContain(`href="/mon-equipe/${ID2}"`);
    expect(html).toContain('aria-disabled="true"');
  });

  it('aucun résultat : le dit', () => {
    const html = rendre({ resultatInitial: { q: 'zzz', groupes: [] }, saisieInitiale: 'zzz' });
    expect(html).toContain('Aucun résultat pour');
    expect(html).toContain('zzz');
  });
});
