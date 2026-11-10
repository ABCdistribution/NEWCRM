import { describe, expect, it, vi } from 'vitest';
import nextConfig from '../../next.config';
import { ONGLETS } from '@/components/admin/onglets';
import { FICHIERS_ROUTES, ID_EXEMPLE, ID_EXEMPLE_2, fichierPourUrl, instancier } from '@/test/pages-reelles';
import { PARAMETRE, appliquer, compiler, echantillons, motifs, suivre } from '@/test/redirections-modele';
import { cheminCompatible } from './chemin';
import { REDIRECTIONS } from './redirections';

// Le composant d'onglets d'administration n'est importé que pour la liste ONGLETS : son lien Next est neutralisé.
vi.mock('next/link', () => ({ default: () => null }));

// La résolution des redirections (première règle qui correspond, :id, :path*) est modélisée dans
// src/test/redirections-modele.ts ; `next build` reste le validateur final de la table (non lancé ici).

const ID = ID_EXEMPLE;
const GENERALE = '/pilotage/:path*';

/**
 * Anciennes adresses -> adresse attendue dans crm-web. Inventaire relevé sur les `src/app` d'ABC Pilot
 * (crm-helios : tout est sous /pilotage) et d'ABC Sales (crm-promoteur) ; l'attendu est écrit à la main.
 */
const CORRESPONDANCES: [ancienne: string, attendue: string][] = [
  // ABC Pilot
  ['/pilotage', '/'],
  ['/pilotage/admin', '/admin'],
  ['/pilotage/alertes', '/alertes'],
  // L'ancienne liste /pilotage/clients était le portefeuille : elle mène à la vue « portefeuille », pas au suivi.
  ['/pilotage/clients', '/clients?vue=portefeuille'],
  [`/pilotage/clients/${ID}`, `/clients/${ID}`],
  ['/pilotage/commandes', '/commandes'],
  [`/pilotage/commandes/${ID}`, `/commandes/${ID}`],
  ['/pilotage/ma-tournee', '/planning'],
  ['/pilotage/magasins', '/clients'],
  [`/pilotage/magasins/${ID}/visite`, `/clients/${ID}/visite`],
  ['/pilotage/mon-equipe', '/mon-equipe'],
  [`/pilotage/mon-equipe/${ID}`, `/mon-equipe/${ID}`],
  [`/pilotage/mon-equipe/${ID}/planning`, `/mon-equipe/${ID}/planning`],
  [`/pilotage/mon-equipe/promoteur/${ID}`, `/mon-equipe/promoteur/${ID}`],
  ['/pilotage/news', '/news'],
  ['/pilotage/parametres', '/parametres'],
  ['/pilotage/planning-equipe', '/planning-equipe'],
  ['/pilotage/produits', '/produits'],
  ['/pilotage/promos', '/promos'],
  ['/pilotage/prospects', '/prospects'],
  [`/pilotage/prospects/${ID}`, `/prospects/${ID}`],
  ['/pilotage/qualite', '/qualite'],
  ['/pilotage/rapports', '/rapports'],
  ['/pilotage/users', '/admin?onglet=utilisateurs'],
  // ABC Sales (pages disparues)
  ['/planification', '/planning-equipe'],
  ['/tournees', '/planning'],
];

/** Adresses inchangées d'ABC Sales (dont l'accueil et /agenda) et adresses communes aux deux anciens fronts. */
const INCHANGEES = [
  '/',
  '/agenda',
  '/clients',
  `/clients/${ID}`,
  '/commandes',
  `/commandes/${ID}`,
  '/news',
  '/parametres',
  '/produits',
  '/promos',
  '/qualite',
  '/visites',
  '/login',
  `/avatar/${ID}`,
  `/pj/${ID}/${ID_EXEMPLE_2}`,
];

describe('structure de la table REDIRECTIONS', () => {
  it('la table n\'est pas vide', () => {
    expect(REDIRECTIONS.length).toBeGreaterThan(0);
  });

  it.each(REDIRECTIONS)('$source : chemin local, requête non attendue, booléen permanent', (regle) => {
    expect(regle.source).toMatch(/^\/(?!\/)[^\\?#\s]*$/); // un seul « / » en tête, ni requête ni ancre dans une source
    expect(typeof regle.permanent).toBe('boolean');
  });

  it.each(REDIRECTIONS)(
    '$destination : destination locale (jamais de site externe, de « // » ni d\'antislash)',
    (regle) => {
      expect(regle.destination).toMatch(/^\/(?!\/)[^\\\s]*$/);
      expect(regle.destination).not.toMatch(/^[a-z][a-z0-9+.-]*:/i);
    },
  );

  it('aucune source en double (la seconde ne servirait jamais)', () => {
    const vues = new Set<string>();
    const doublons: string[] = [];
    for (const { source } of REDIRECTIONS) {
      const cle = source.toLowerCase();
      if (vues.has(cle)) doublons.push(source);
      vues.add(cle);
    }
    expect(doublons).toEqual([]);
  });

  it('syntaxe des sources : seuls « :nom » et « :nom* » sont utilisés (la seule que ce test sait évaluer)', () => {
    expect(() => REDIRECTIONS.forEach(compiler)).not.toThrow();
  });

  it('chaque paramètre de la destination est défini par la source', () => {
    const inconnus: string[] = [];
    for (const regle of REDIRECTIONS) {
      const definis = new Set(compiler(regle).parametres);
      for (const segment of regle.destination.split('?')[0].split('/')) {
        const parametre = PARAMETRE.exec(segment);
        if (parametre && !definis.has(parametre[1])) inconnus.push(`${regle.source} -> ${regle.destination} (:${parametre[1]})`);
      }
    }
    expect(inconnus).toEqual([]);
  });
});

describe('destinations', () => {
  it.each(CORRESPONDANCES)('%s mène à %s', (ancienne, attendue) => {
    const arrivee = suivre(ancienne);
    expect(arrivee.boucle).toBe(false);
    expect(arrivee.chemin).toBe(attendue);
  });

  it.each(CORRESPONDANCES)('%s : l\'adresse d\'arrivée est une vraie page de crm-web', (ancienne) => {
    const arrivee = suivre(ancienne).chemin;
    expect(fichierPourUrl(arrivee), `${ancienne} -> ${arrivee} : aucune page ne sert cette adresse`).toBeDefined();
  });

  it.each(REDIRECTIONS.filter((r) => !r.destination.includes('*')))(
    '$source : la destination est une page réelle, pour chaque forme de la source',
    (regle) => {
      for (const echantillon of echantillons(regle.source)) {
        const etape = appliquer(echantillon);
        expect(etape?.regle, `${echantillon} devrait être redirigée par ${regle.source}`).toBe(regle);
        expect(
          fichierPourUrl(etape!.destination),
          `${echantillon} -> ${etape!.destination} : aucune page ne sert cette adresse`,
        ).toBeDefined();
      }
    },
  );

  it('la règle générale ne retire que le préfixe /pilotage (le reste du chemin est conservé tel quel)', () => {
    expect(appliquer('/pilotage/xxx')?.destination).toBe('/xxx');
    expect(appliquer('/pilotage/xxx/yyy')?.destination).toBe('/xxx/yyy');
    expect(appliquer('/pilotage/xxx')?.regle.source).toBe(GENERALE);
  });

  it('la requête d\'une destination vers /clients désigne une vue qui existe (suivi par défaut, ou portefeuille)', () => {
    const vues = REDIRECTIONS.map((r) => r.destination)
      .filter((d) => d.startsWith('/clients?'))
      .map((d) => new URLSearchParams(d.split('?')[1]).get('vue'));
    expect(vues.length).toBeGreaterThan(0);
    for (const vue of vues) expect(['portefeuille']).toContain(vue);
  });

  it('la requête d\'une destination vers /admin désigne un onglet qui existe', () => {
    const ongletsConnus = ONGLETS.map((o) => o.id);
    const destinations = REDIRECTIONS.map((r) => r.destination).filter((d) => d.startsWith('/admin?'));
    expect(destinations.length).toBeGreaterThan(0);
    for (const destination of destinations) {
      const onglet = new URLSearchParams(destination.split('?')[1]).get('onglet');
      expect(ongletsConnus, destination).toContain(onglet);
    }
  });
});

describe('sources', () => {
  it('aucune source ne coïncide avec une page ou un route handler réel (la redirection le masquerait)', () => {
    const masquees = FICHIERS_ROUTES.flatMap((fichier) => {
      const exemple = instancier(fichier.url);
      const motif = motifs().find((m) => m.regex.test(exemple));
      return motif ? [`${fichier.fichier} (${exemple}) masquée par ${motif.regle.source}`] : [];
    });
    expect(masquees).toEqual([]);
  });

  it.each(INCHANGEES)('%s : adresse inchangée, servie sans redirection', (adresse) => {
    expect(appliquer(adresse)).toBeNull();
    expect(fichierPourUrl(adresse, ['page', 'route']), `${adresse} : aucune page ni route`).toBeDefined();
  });

  it('les sources ne servent qu\'aux anciennes adresses : /pilotage…, /tournees, /planification', () => {
    const etrangeres = REDIRECTIONS.map((r) => r.source).filter(
      (s) => !(s === '/pilotage' || s.startsWith('/pilotage/') || s === '/tournees' || s === '/planification'),
    );
    expect(etrangeres).toEqual([]);
  });
});

describe('boucles et chaînes', () => {
  const toutesLesAdresses = [
    ...REDIRECTIONS.flatMap((r) => echantillons(r.source)),
    ...CORRESPONDANCES.map(([ancienne]) => ancienne),
  ];

  it('aucune redirection ne tourne en boucle (chaque adresse atteint une page sans redirection)', () => {
    const boucles = toutesLesAdresses.filter((adresse) => suivre(adresse).boucle);
    expect(boucles).toEqual([]);
  });

  it('une seule redirection suffit : aucune destination n\'est elle-même redirigée', () => {
    const chaines = toutesLesAdresses
      .map((adresse) => ({ adresse, saut: suivre(adresse).sauts }))
      .filter(({ saut }) => saut > 1)
      .map(({ adresse, saut }) => `${adresse} : ${saut} sauts`);
    expect(chaines).toEqual([]);
  });

  it('aucune redirection vers /login ni vers l\'ancien préfixe /pilotage', () => {
    for (const regle of REDIRECTIONS) {
      expect(regle.destination, regle.source).not.toMatch(/^\/login(?:[/?#]|$)/);
      expect(regle.destination, regle.source).not.toMatch(/^\/pilotage(?:[/?#]|$)/);
    }
  });
});

describe('ordre des règles (la première qui correspond l\'emporte)', () => {
  it(`la règle générale ${GENERALE} existe et vient EN DERNIER`, () => {
    const index = REDIRECTIONS.findIndex((r) => r.source === GENERALE);
    expect(index).toBeGreaterThanOrEqual(0);
    expect(index).toBe(REDIRECTIONS.length - 1);
  });

  it(`toute règle spécifique /pilotage… précède ${GENERALE}`, () => {
    const generale = REDIRECTIONS.findIndex((r) => r.source === GENERALE);
    const apres = REDIRECTIONS.map((r, index) => ({ r, index }))
      .filter(({ r, index }) => r.source.startsWith('/pilotage') && r.source !== GENERALE && index > generale)
      .map(({ r }) => r.source);
    expect(apres).toEqual([]);
  });

  it('pour sa propre adresse, chaque règle spécifique l\'emporte sur la règle générale', () => {
    const specifiques = REDIRECTIONS.filter((r) => r.source !== GENERALE);
    for (const regle of specifiques) {
      for (const echantillon of echantillons(regle.source)) {
        expect(appliquer(echantillon)?.regle.source, echantillon).toBe(regle.source);
      }
    }
  });

  it('aucune règle n\'est masquée par une règle placée avant elle (au moins une adresse l\'atteint)', () => {
    const inatteignables = REDIRECTIONS.filter(
      (regle, index) => !echantillons(regle.source).some((e) => appliquer(e)?.index === index),
    ).map((r) => r.source);
    expect(inatteignables).toEqual([]);
  });
});

describe('cohérence avec cheminCompatible (liens de notification affichés par l\'application)', () => {
  it.each(['/tournees', '/pilotage/ma-tournee'])(
    'lien enregistré par l\'API (%s) : même cible que la table de redirections',
    (lien) => {
      expect(cheminCompatible(lien)).toBe(appliquer(lien)?.destination);
    },
  );

  // cheminCompatible dérive de la table REDIRECTIONS (source de vérité unique) : il applique la même première règle
  // que redirects(), y compris les règles spécifiques (/pilotage/magasins -> /clients) et non le seul retrait du préfixe.
  it.each(CORRESPONDANCES)('%s : cheminCompatible mène à la même adresse que la table (%s)', (ancienne, attendue) => {
    expect(cheminCompatible(ancienne)).toBe(attendue);
    expect(cheminCompatible(ancienne)).toBe(appliquer(ancienne)?.destination);
  });

  it('toute adresse qu\'une règle de la table redirige est traduite comme la table (adresses d\'exemple de chaque source)', () => {
    const ecarts: string[] = [];
    for (const regle of REDIRECTIONS) {
      for (const echantillon of echantillons(regle.source)) {
        const attendu = appliquer(echantillon)?.destination;
        const obtenu = cheminCompatible(echantillon);
        if (obtenu !== attendu) ecarts.push(`${echantillon} : ${obtenu} au lieu de ${attendu}`);
      }
    }
    expect(ecarts).toEqual([]);
  });

  it('l\'ancienne requête (?search=, ?page=) est conservée, celle de la destination l\'emporte en cas de doublon', () => {
    expect(cheminCompatible('/pilotage/clients?search=abc&page=2')).toBe('/clients?search=abc&page=2&vue=portefeuille');
    expect(cheminCompatible('/pilotage/clients?vue=suivi')).toBe('/clients?vue=portefeuille');
  });

  // Anciennes adresses que cheminCompatible traduit en une adresse qui, elle, n'est plus servie par une page.
  it('tout ancien lien traduit par cheminCompatible reste servi par une page', () => {
    const cassees = CORRESPONDANCES.map(([ancienne]) => ancienne).filter((ancienne) => {
      const traduit = cheminCompatible(ancienne);
      return traduit !== null && !fichierPourUrl(suivre(traduit).chemin);
    });
    expect(cassees).toEqual([]);
  });
});

describe('statut des redirections', () => {
  // La table n'est pas stabilisée (cible de /pilotage/clients, MARKETING et ADV, migration en cours) : un 308 est
  // mis en cache durablement par les navigateurs. Ce test décrit l'état PROVISOIRE : le supprimer (ou le renverser)
  // quand PERMANENT passe à true, à la mise en production.
  it('toutes les redirections sont temporaires (307) tant que la table n\'est pas figée', () => {
    expect(REDIRECTIONS.filter((r) => r.permanent).map((r) => r.source)).toEqual([]);
  });
});

describe('next.config.ts', () => {
  it('redirects() expose exactement la table REDIRECTIONS', async () => {
    expect(nextConfig.redirects).toBeTypeOf('function');
    expect(await nextConfig.redirects!()).toEqual(REDIRECTIONS);
  });

  it('redirects() renvoie des copies : Next modifie les objets reçus, la table partagée reste intacte', async () => {
    const avant = structuredClone(REDIRECTIONS);
    const copies = await nextConfig.redirects!();
    expect(copies[0]).not.toBe(REDIRECTIONS[0]);
    for (const copie of copies) Object.assign(copie, { source: '/modifiee', statusCode: 418 });
    expect(REDIRECTIONS).toEqual(avant);
  });
});
