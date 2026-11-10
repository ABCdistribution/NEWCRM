import { describe, expect, it } from 'vitest';
import { lireFichierApp, lireGarde } from '@/test/gardes-pages';
import { FICHIERS_ROUTES, PAGES } from '@/test/pages-reelles';
import { ENCADREMENT, ROLES_COMMANDES_VISITES, TERRAIN, TOUS_ROLES, espaceDe, type Role } from './roles';
import { ROUTES, routesMenu } from './routes';

// Aucun mock : la table, les rôles et les icônes lucide sont les vrais ; seul le disque (src/app) est lu.

const trie = (roles: readonly string[]): string[] => [...roles].sort();
const estDynamique = (url: string): boolean => url.includes('[');

/** Rôles (triés) de la table pour une URL de page, ou undefined si la table ne la connaît pas. */
const rolesDeLaTable = (url: string): string[] | undefined => {
  const route = ROUTES.find((r) => r.href === url);
  return route ? trie(route.roles) : undefined;
};

/**
 * Pages qui existent sans figurer dans ROUTES. Chaque entrée est une décision consciente : ajouter ici
 * une page, c'est dire qu'elle n'a ni entrée de menu ni règle de rôles dans la table.
 */
const HORS_TABLE = new Map<string, string>([
  ['/login', 'page publique de connexion (hors du groupe (app))'],
  ['/users', "redirection pure vers /admin?onglet=utilisateurs (la page /admin rappelle requireRole(['ADMIN']))"],
]);

/** Route handlers attendus (hors table : ils relaient l'API avec le JWT du cookie, l'API reste juge). */
const ROUTE_HANDLERS_ATTENDUS = ['/avatar/[id]', '/pj/[id]/[pjId]'];

describe('table ROUTES', () => {
  it('aucun href en double', () => {
    const vus = new Set<string>();
    const doublons: string[] = [];
    for (const route of ROUTES) {
      if (vus.has(route.href)) doublons.push(route.href);
      vus.add(route.href);
    }
    expect(doublons).toEqual([]);
  });

  it.each(ROUTES)('$href : entrée bien formée', (route) => {
    expect(route.href).toMatch(/^\/(?:[a-z0-9-]+(?:\/[a-z0-9-]+)*)?$/); // « / » ou « /mot[/mot] », sans « / » final
    expect(route.label.trim()).not.toBe('');
    expect(route.icon, `icône absente de lucide-react pour ${route.href}`).toBeTruthy();
    expect(['commun', 'direction', 'promoteurs']).toContain(route.espace);
    expect(route.roles.length).toBeGreaterThan(0);
    expect(new Set(route.roles).size).toBe(route.roles.length);
    expect(route.roles.filter((r) => !TOUS_ROLES.includes(r))).toEqual([]);
  });

  it("une route « direction » n'autorise que des rôles de l'encadrement", () => {
    const intrus = ROUTES.filter((r) => r.espace === 'direction').flatMap((r) =>
      r.roles.filter((role) => !ENCADREMENT.includes(role)).map((role) => `${r.href} : ${role}`),
    );
    expect(intrus).toEqual([]);
  });
});

describe('pages réelles sous src/app', () => {
  it.each(ROUTES)('$href a une vraie page', (route) => {
    const page = PAGES.find((p) => p.url === route.href);
    expect(page, `aucun page.tsx ne sert ${route.href} sous src/app`).toBeDefined();
  });

  it("aucune URL n'est servie par deux fichiers (Next refuserait de construire)", () => {
    const parUrl = new Map<string, string[]>();
    for (const f of FICHIERS_ROUTES) parUrl.set(f.url, [...(parUrl.get(f.url) ?? []), f.fichier]);
    const doublons = [...parUrl].filter(([, fichiers]) => fichiers.length > 1);
    expect(doublons).toEqual([]);
  });

  it.each(ROUTES)("$href : le groupe de routes de la page correspond à l'espace « $espace »", (route) => {
    const groupes = PAGES.find((p) => p.url === route.href)?.groupes ?? [];
    // « commun » vit directement sous (app) ; « direction » sous (direction) ; « promoteurs » sous (promoteurs).
    expect(groupes.includes('direction')).toBe(route.espace === 'direction');
    expect(groupes.includes('promoteurs')).toBe(route.espace === 'promoteurs');
  });

  it('toute page statique est dans ROUTES, ou connue comme hors table', () => {
    const inconnues = PAGES.filter(
      (p) => !estDynamique(p.url) && !ROUTES.some((r) => r.href === p.url) && !HORS_TABLE.has(p.url),
    ).map((p) => p.fichier);
    // Nouvelle page : l'ajouter à ROUTES (menu + rôles) ou à HORS_TABLE avec sa justification.
    expect(inconnues).toEqual([]);
  });

  it("toute page de détail dépend d'une route déclarée (donc d'une règle de rôles)", () => {
    const orphelines = PAGES.filter((p) => estDynamique(p.url)).filter(
      (p) => !ROUTES.some((r) => r.href === `/${p.url.split('/')[1]}`),
    );
    expect(orphelines.map((p) => p.fichier)).toEqual([]);
  });

  it('seule /login est publique : toute autre page est dans le groupe (app)', () => {
    const publiques = PAGES.filter((p) => !p.groupes.includes('app')).map((p) => p.url);
    expect(publiques).toEqual(['/login']);
  });

  it('le layout (app) renvoie vers /login quand il n\'y a pas de session', () => {
    expect(lireFichierApp('(app)/layout.tsx')).toMatch(
      /await lireSession\(\);\s*if \(session\.etat === 'absente'\) redirect\(await urlLogin\(\)\)/,
    );
  });

  it('le layout (app) n\'envoie PAS vers /login quand l\'API est indisponible (écran dédié, session conservée)', () => {
    const code = lireFichierApp('(app)/layout.tsx');
    expect(code).toMatch(/if \(session\.etat === 'indisponible'\) return <ServiceIndisponible \/>/);
    expect(code).not.toMatch(/redirect\('\/login'\)/);
  });

  it('les route handlers sont exactement ceux attendus (toute nouvelle route est à relire côté sécurité)', () => {
    const handlers = FICHIERS_ROUTES.filter((f) => f.type === 'route').map((f) => f.url);
    expect(trie(handlers)).toEqual(trie(ROUTE_HANDLERS_ATTENDUS));
  });
});

describe('gardes des pages et des layouts (requireRole) face à la table', () => {
  const connus = { TOUS_ROLES, ENCADREMENT, TERRAIN, ROLES_COMMANDES_VISITES };
  const pagesDeApp = PAGES.filter((p) => p.groupes[0] === 'app');

  /** Rôles de la garde d'un fichier de src/app ; erreur explicite si elle n'est pas lisible. */
  const rolesDeGarde = (fichier: string): string[] => {
    const garde = lireGarde(lireFichierApp(fichier), connus);
    if ('erreur' in garde) throw new Error(`${fichier} : ${garde.erreur}`);
    return garde.roles;
  };
  const pageDe = (url: string) => {
    const page = pagesDeApp.find((p) => p.url === url);
    if (!page) throw new Error(`aucune page ${url} dans (app)`);
    return page;
  };

  /**
   * Écarts CONNUS : la garde de la page n'est pas égale aux rôles de la table. Documentés ici plutôt
   * qu'effacés : voir les deux tests dédiés plus bas.
   */
  const ECARTS_CONNUS = new Map<string, { plus: string[]; moins: string[] }>([
    // La page ouvre sa vue « lecture » à tout TERRAIN (donc ADV) ; la table ne liste que COMMERCIAL. ADV : à définir.
    ['/planning', { plus: ['ADV'], moins: [] }],
  ]);

  it("le layout (direction) ne laisse entrer que l'encadrement", () => {
    expect(rolesDeGarde('(app)/(direction)/layout.tsx')).toEqual(trie(ENCADREMENT));
  });

  it("le layout (promoteurs) laisse entrer l'encadrement (décision : il garde l'accès aux écrans terrain)", () => {
    const roles = rolesDeGarde('(app)/(promoteurs)/layout.tsx');
    expect(ENCADREMENT.filter((r) => !roles.includes(r))).toEqual([]);
  });

  it('toute page de (app) appelle requireRole, sauf les redirections pures connues', () => {
    const sansGarde: string[] = [];
    for (const page of pagesDeApp.filter((p) => !HORS_TABLE.has(p.url))) {
      const garde = lireGarde(lireFichierApp(page.fichier), connus);
      if ('erreur' in garde) sansGarde.push(`${page.fichier} : ${garde.erreur}`);
    }
    expect(sansGarde).toEqual([]);
  });

  it("les pages hors table de (app) restent de simples redirections (ni garde ni appel à l'API)", () => {
    const horsTableDeApp = pagesDeApp.filter((p) => HORS_TABLE.has(p.url));
    expect(horsTableDeApp.length).toBeGreaterThan(0);
    for (const page of horsTableDeApp) {
      const code = lireFichierApp(page.fichier);
      expect(code, page.fichier).toMatch(/\bredirect\(/);
      expect(code, page.fichier).not.toMatch(/@\/lib\/api|serverFetch|getMe/);
      expect(code, page.fichier).not.toMatch(/await requireRole\(/);
    }
  });

  it.each(ROUTES.filter((r) => !ECARTS_CONNUS.has(r.href)))('$href : la garde de la page = les rôles de la table', (route) => {
    expect(rolesDeGarde(pageDe(route.href).fichier)).toEqual(trie(route.roles));
  });

  describe('écarts connus (à résoudre avec la décision métier sur ADV)', () => {
    it.fails('/planning : la garde de la page = les rôles de la table (écart connu : ADV)', () => {
      expect(rolesDeGarde(pageDe('/planning').fichier)).toEqual(rolesDeLaTable('/planning'));
    });

    it("/planning : l'écart se limite à ADV (admis par la page, absent de la table)", () => {
      const page = rolesDeGarde(pageDe('/planning').fichier);
      const table = rolesDeLaTable('/planning') ?? [];
      expect({
        plus: page.filter((r) => !table.includes(r)),
        moins: table.filter((r) => !page.includes(r)),
      }).toEqual(ECARTS_CONNUS.get('/planning'));
    });
  });

  it.each(pagesDeApp.filter((p) => estDynamique(p.url)))(
    "$url : la garde de la page de détail n'est pas plus large que celle de sa route",
    (page) => {
      const parent = rolesDeLaTable(`/${page.url.split('/')[1]}`) ?? [];
      expect(rolesDeGarde(page.fichier).filter((r) => !parent.includes(r))).toEqual([]);
    },
  );
});

describe('routesMenu', () => {
  /** Menu d'un rôle dans son propre espace (comme le layout de l'application). */
  const menu = (role: Role): string[] => routesMenu(role, espaceDe(role)).map((r) => r.href);

  /** Écrans communs à tous les profils d'encadrement. */
  const BASE_ENCADREMENT = [
    '/',
    '/news',
    '/clients',
    '/commandes',
    '/visites',
    '/produits',
    '/promos',
    '/qualite',
    '/planning',
    '/planning-equipe',
    '/prospects',
    '/alertes',
  ];

  describe('tous les rôles', () => {
    it.each(TOUS_ROLES)("%s voit l'accueil et les news", (role) => {
      expect(menu(role)).toContain('/');
      expect(menu(role)).toContain('/news');
    });

    it.each(TOUS_ROLES)("%s : seul l'ADMIN voit /admin", (role) => {
      expect(menu(role).includes('/admin')).toBe(role === 'ADMIN');
    });

    it.each(TOUS_ROLES)('%s : menu sans doublon, composé de routes de menu autorisées', (role) => {
      const hrefs = menu(role);
      expect(new Set(hrefs).size).toBe(hrefs.length);
      for (const route of routesMenu(role, espaceDe(role))) {
        expect(route.menu, `${route.href} n'est pas une route de menu`).toBe(true);
        expect(route.roles, `${route.href} est interdite à ${role}`).toContain(role);
      }
    });

    it("le marketing n'a accès ni aux commandes ni aux visites : ni menu, ni route, ni page", () => {
      expect(ROLES_COMMANDES_VISITES).not.toContain('MARKETING');
      for (const role of TOUS_ROLES.filter((r) => r !== 'MARKETING')) expect(ROLES_COMMANDES_VISITES).toContain(role);
      for (const espace of ['promoteurs', 'direction'] as const) {
        const hrefs = routesMenu('MARKETING', espace).map((r) => r.href);
        expect(hrefs).not.toContain('/commandes');
        expect(hrefs).not.toContain('/visites');
      }
      for (const href of ['/commandes', '/visites']) {
        expect(ROUTES.find((r) => r.href === href)?.roles).not.toContain('MARKETING');
      }
      // Les autres écrans du marketing sont inchangés : clients, produits, promos, qualité, news.
      const hrefs = routesMenu('MARKETING', 'promoteurs').map((r) => r.href);
      for (const href of ['/', '/news', '/clients', '/produits', '/promos', '/qualite']) expect(hrefs).toContain(href);
    });

    it("le filtre par rôle s'applique quel que soit l'espace demandé (jamais une route interdite)", () => {
      const fuites: string[] = [];
      for (const role of TOUS_ROLES) {
        for (const espace of ['promoteurs', 'direction'] as const) {
          for (const route of routesMenu(role, espace)) {
            if (!route.roles.includes(role)) fuites.push(`${role} / ${espace} : ${route.href}`);
          }
        }
      }
      expect(fuites).toEqual([]);
    });

    it("le paramètre espace écarte les routes propres à l'autre espace (« commun » reste visible partout)", () => {
      // Pas de route de menu propre à « promoteurs » aujourd'hui : on ne vérifie que le sens « direction ».
      const propresDirection = ROUTES.filter((r) => r.menu && r.espace === 'direction').map((r) => r.href);
      expect(propresDirection.length).toBeGreaterThan(0);
      // ADMIN est autorisé sur toutes les routes de menu : seul l'espace demandé peut donc en retirer.
      const chezPromoteurs = routesMenu('ADMIN', 'promoteurs').map((r) => r.href);
      for (const href of propresDirection) expect(chezPromoteurs, href).not.toContain(href);
      for (const route of ROUTES.filter((r) => r.menu && r.espace === 'commun' && r.roles.includes('ADMIN'))) {
        expect(chezPromoteurs, route.href).toContain(route.href);
      }
      expect(routesMenu('ADMIN', 'direction').map((r) => r.href)).toEqual(expect.arrayContaining(propresDirection));
    });

    it('aucune entrée de menu « morte » : chaque rôle autorisé voit la route dans le menu de son espace', () => {
      const mortes: string[] = [];
      for (const route of ROUTES.filter((r) => r.menu)) {
        for (const role of route.roles) {
          if (!menu(role).includes(route.href)) mortes.push(`${route.href} (${role})`);
        }
      }
      expect(mortes).toEqual([]);
    });
  });

  describe('menu exact des profils décidés (toute évolution des droits doit apparaître dans ce test)', () => {
    it('COMMERCIAL : ni /admin, ni /rapports, ni /mon-equipe, ni /prospects', () => {
      const hrefs = menu('COMMERCIAL');
      for (const interdite of ['/admin', '/rapports', '/mon-equipe', '/prospects']) {
        expect(hrefs).not.toContain(interdite);
      }
    });

    it("COMMERCIAL : accueil, news et écrans terrain (planning personnel, pas le planning d'équipe)", () => {
      expect(trie(menu('COMMERCIAL'))).toEqual(
        trie(['/', '/news', '/clients', '/commandes', '/visites', '/produits', '/promos', '/qualite', '/planning']),
      );
    });

    it('CHEF_SECTEUR : ni /rapports ni /admin ; il voit Mon équipe', () => {
      const hrefs = menu('CHEF_SECTEUR');
      expect(hrefs).not.toContain('/rapports');
      expect(hrefs).not.toContain('/admin');
      expect(hrefs).toContain('/mon-equipe');
      expect(trie(hrefs)).toEqual(trie([...BASE_ENCADREMENT, '/mon-equipe']));
    });

    it("DIRECTION : ni /mon-equipe ni /admin ; elle voit les rapports d'activité", () => {
      const hrefs = menu('DIRECTION');
      expect(hrefs).not.toContain('/mon-equipe');
      expect(hrefs).not.toContain('/admin');
      expect(hrefs).toContain('/rapports');
      expect(trie(hrefs)).toEqual(trie([...BASE_ENCADREMENT, '/rapports']));
    });

    it('DIRECTEUR_REGIONAL : Mon équipe et rapports, pas /admin', () => {
      expect(trie(menu('DIRECTEUR_REGIONAL'))).toEqual(trie([...BASE_ENCADREMENT, '/mon-equipe', '/rapports']));
    });

    it("ADMIN : voit /admin en plus de tout l'espace Direction", () => {
      expect(menu('ADMIN')).toContain('/admin');
      expect(trie(menu('ADMIN'))).toEqual(trie([...BASE_ENCADREMENT, '/mon-equipe', '/rapports', '/admin']));
    });

    it("/agenda n'est dans aucun menu (page « bientôt »)", () => {
      for (const role of TOUS_ROLES) expect(menu(role)).not.toContain('/agenda');
    });
  });
});
