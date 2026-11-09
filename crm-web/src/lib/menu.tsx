import { createElement, type ReactNode } from 'react';
import { routesMenu } from './routes';
import { espaceDe, type Espace, type Role } from './roles';

/** Entrée de menu sérialisable (l'icône est un élément React, pas une fonction). */
export type MenuItem = { href: string; label: string; icon: ReactNode };
export type MenuSection = { label: string | null; items: MenuItem[] };

/**
 * Regroupement visuel du menu. Les routes elles-mêmes (rôles, libellés, icônes) viennent de
 * la table unique `ROUTES` ; seul le découpage en sections est défini ici.
 */
const SECTIONS: { cle: string; label: (role: Role) => string | null; hrefs: string[] }[] = [
  { cle: 'general', label: () => null, hrefs: ['/', '/news'] },
  {
    cle: 'terrain',
    label: (role) => (role === 'COMMERCIAL' ? 'Mon terrain' : 'Terrain'),
    hrefs: ['/planning', '/planning-equipe', '/clients', '/visites', '/commandes'],
  },
  { cle: 'catalogue', label: () => 'Catalogue', hrefs: ['/produits', '/promos', '/qualite'] },
  { cle: 'pilotage', label: () => 'Pilotage', hrefs: ['/prospects', '/mon-equipe', '/alertes', '/rapports'] },
  { cle: 'admin', label: () => 'Administration', hrefs: ['/admin'] },
];

/** Libellés propres à un rôle (sinon celui de la table ROUTES). */
function libelle(href: string, role: Role, defaut: string): string {
  // Le planning de l'encadrement est le planning d'activité (prospection + suivi magasins).
  if (href === '/planning' && role !== 'COMMERCIAL') return "Mon planning d'activité";
  return defaut;
}

/** Menu d'un utilisateur : routes de `routesMenu` rangées en sections. */
export function construireMenu(role: Role, espace: Espace = espaceDe(role)): MenuSection[] {
  const routes = routesMenu(role, espace);
  const dejaPlacees = new Set<string>();
  const sections: MenuSection[] = [];

  const versItem = (href: string): MenuItem | null => {
    const r = routes.find((x) => x.href === href);
    if (!r) return null;
    dejaPlacees.add(href);
    return {
      href: r.href,
      label: libelle(r.href, role, r.label),
      icon: createElement(r.icon, { size: 19, 'aria-hidden': true }),
    };
  };

  for (const s of SECTIONS) {
    const items = s.hrefs.map(versItem).filter((i): i is MenuItem => i !== null);
    if (items.length > 0) sections.push({ label: s.label(role), items });
  }

  // Filet de sécurité : une route de menu absente des sections ne disparaît pas.
  const autres = routes
    .filter((r) => !dejaPlacees.has(r.href))
    .map((r) => versItem(r.href))
    .filter((i): i is MenuItem => i !== null);
  if (autres.length > 0) sections.push({ label: 'Autres', items: autres });

  return sections;
}
