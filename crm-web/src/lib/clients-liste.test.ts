import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { ClientsListe } from '@/components/clients-liste';
import { aUnPerimetre, lireFiltresClients, type ClientListe } from './clients-liste';

// La barre de filtres lit l'adresse et réécrit l'URL : routeur et paramètres sont remplacés par des coquilles.
vi.mock('next/navigation', () => ({
  useRouter: () => ({ replace: () => undefined, push: () => undefined }),
  usePathname: () => '/clients',
  useSearchParams: () => new URLSearchParams(),
}));
const { ClientsFiltres } = await import('@/components/clients-filtres');

describe('filtres lus dans l’adresse', () => {
  it('valeurs par défaut : clients actifs, page 1, « Mes clients » pour les rôles qui ont un périmètre', () => {
    expect(lireFiltresClients({}, 'COMMERCIAL')).toEqual({ search: '', page: 1, niveau: undefined, statut: 'actifs', mes: true, tous: false });
    expect(lireFiltresClients({}, 'CHEF_SECTEUR').mes).toBe(true);
    expect(lireFiltresClients({}, 'DIRECTEUR_REGIONAL').mes).toBe(true);
  });

  it('pas de « Mes clients » pour le siège, la direction, l’admin, l’ADV et le marketing', () => {
    for (const role of ['ADMIN', 'DIRECTION', 'ADV', 'MARKETING'] as const) {
      expect(lireFiltresClients({}, role).mes).toBe(false);
      expect(aUnPerimetre(role)).toBe(false);
    }
  });

  it('tous=1 sort de « Mes clients »', () => {
    expect(lireFiltresClients({ tous: '1' }, 'CHEF_SECTEUR').mes).toBe(false);
    expect(lireFiltresClients({ tous: '1' }, 'CHEF_SECTEUR').tous).toBe(true);
    expect(lireFiltresClients({ tous: '1' }, 'ADMIN').tous).toBe(false); // sans périmètre : rien à lever
    expect(lireFiltresClients({ tous: '0' }, 'CHEF_SECTEUR').mes).toBe(true);
  });

  it('statut, niveau et page : seules les valeurs attendues passent', () => {
    expect(lireFiltresClients({ statut: 'inactifs' }, 'ADMIN').statut).toBe('inactifs');
    expect(lireFiltresClients({ statut: 'tous' }, 'ADMIN').statut).toBe('tous');
    expect(lireFiltresClients({ statut: 'n_importe_quoi' }, 'ADMIN').statut).toBe('actifs');
    expect(lireFiltresClients({ niveau: 'D' }, 'ADMIN').niveau).toBe('D');
    expect(lireFiltresClients({ niveau: 'aucun' }, 'ADMIN').niveau).toBe('aucun');
    expect(lireFiltresClients({ niveau: 'Z' }, 'ADMIN').niveau).toBeUndefined();
    expect(lireFiltresClients({ niveau: 'A;DROP' }, 'ADMIN').niveau).toBeUndefined();
    expect(lireFiltresClients({ page: '3' }, 'ADMIN').page).toBe(3);
    expect(lireFiltresClients({ page: '0' }, 'ADMIN').page).toBe(1);
    expect(lireFiltresClients({ page: '-2' }, 'ADMIN').page).toBe(1);
    expect(lireFiltresClients({ page: '1e9' }, 'ADMIN').page).toBe(1);
  });

  it('le texte cherché est nettoyé et borné à 80 caractères', () => {
    expect(lireFiltresClients({ search: '  auchan rouen  ' }, 'ADMIN').search).toBe('auchan rouen');
    expect(lireFiltresClients({ search: 'x'.repeat(200) }, 'ADMIN').search).toHaveLength(80);
  });
});

const ID = '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50';
const MAINTENANT = Date.parse('2026-11-10T12:00:00Z');
const CLIENT = (plus: Partial<ClientListe> = {}): ClientListe => ({
  id: ID,
  codeAs400: '112003',
  enseigne: '735 MATCH 67 STRASBOURG ROBERT',
  raisonSociale: 'MATCH SAS',
  ville: 'STRASBOURG ROBERTSAU',
  codePostal: '67000',
  niveauClass: 'D',
  actif: true,
  createdAt: '2020-01-01T00:00:00Z',
  ...plus,
});
const rendreListe = (clients: ClientListe[]) => renderToStaticMarkup(createElement(ClientsListe, { clients, maintenant: MAINTENANT }));

describe('liste des clients', () => {
  it('colonnes Enseigne, Code AS400, Ville / CP, Niveau, Statut, et ligne cliquable vers la fiche', () => {
    const html = rendreListe([CLIENT()]);
    for (const titre of ['Enseigne', 'Code AS400', 'Ville / CP', 'Niveau', 'Statut']) expect(html).toContain(titre);
    expect(html).toContain('735 MATCH 67 STRASBOURG ROBERT');
    expect(html).toContain('112003');
    expect(html).toContain('STRASBOURG ROBERTSAU · 67000');
    expect(html).toContain(`href="/clients/${ID}"`);
    expect(html).toContain('after:absolute'); // toute la ligne est cliquable
    expect(html).toContain('Actif');
    expect(html).toContain('title="Classe D"');
  });

  it('pastille « Nouveau » seulement pour un client créé depuis moins de 30 jours', () => {
    expect(rendreListe([CLIENT({ createdAt: '2026-11-01T00:00:00Z' })])).toContain('Nouveau');
    expect(rendreListe([CLIENT({ createdAt: '2026-09-01T00:00:00Z' })])).not.toContain('Nouveau');
    expect(rendreListe([CLIENT({ createdAt: 'pas une date' })])).not.toContain('Nouveau');
  });

  it('client inactif, sans niveau, sans ville : affichés proprement', () => {
    const html = rendreListe([CLIENT({ actif: false, niveauClass: null, ville: null, codePostal: null })]);
    expect(html).toContain('Inactif');
    expect(html).not.toContain('title="Classe');
    expect(html).toContain('—');
  });

  it('aucun client : le dit', () => {
    expect(rendreListe([])).toContain('Aucun client pour ces filtres.');
  });
});

describe('barre de filtres', () => {
  const rendre = (plus: Partial<Parameters<typeof ClientsFiltres>[0]> = {}) =>
    renderToStaticMarkup(createElement(ClientsFiltres, { search: '', statut: 'actifs', mes: true, avecMes: true, ...plus }));

  it('recherche, niveau, état et « Mes clients » sont proposés ; Réinitialiser inactif sans filtre modifié', () => {
    const html = rendre();
    expect(html).toContain('Rechercher par enseigne, code AS400, ville, CP');
    expect(html).toContain('Tous les niveaux');
    expect(html).toContain('Clients actifs');
    expect(html).toContain('Clients inactifs');
    expect(html).toContain('Mes clients');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*>.*Réinitialiser/s);
  });

  it('sans périmètre : pas de « Mes clients »', () => {
    expect(rendre({ avecMes: false, mes: false })).not.toContain('Mes clients');
  });

  it('un filtre modifié active « Réinitialiser »', () => {
    expect(rendre({ niveau: 'D' })).not.toMatch(/<button[^>]*disabled=""[^>]*>.*Réinitialiser/s);
    expect(rendre({ mes: false })).not.toMatch(/<button[^>]*disabled=""[^>]*>.*Réinitialiser/s);
  });
});
