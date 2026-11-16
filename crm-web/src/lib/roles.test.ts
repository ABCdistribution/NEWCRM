import { isValidElement } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AccesRefuse } from '@/components/acces-refuse';
import type { Me, Role } from './api';
import {
  ENCADREMENT,
  ENTETE_CHEMIN,
  ErreurServiceIndisponible,
  TERRAIN,
  TOUS_ROLES,
  espaceDe,
  estEncadrement,
  exigerRole,
  lireSession,
  requireRole,
  urlLogin,
} from './roles';

// `serverFetch` (appel réseau vers l'API), `next/navigation` et `next/headers` sont remplacés : aucune session,
// aucun réseau. L'API répond ce que le test décide (`apiRepond`), comme GET /auth/me.
const mocks = vi.hoisted(() => ({
  serverFetch: vi.fn(),
  redirect: vi.fn(),
  headers: vi.fn(),
  rethrow: vi.fn(),
}));
// Seul `serverFetch` est remplacé : `projeterMe` (fonction pure) reste celle d'api.ts.
vi.mock('./api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./api')>()),
  serverFetch: mocks.serverFetch,
}));
// `unstable_rethrow` : sans effet par défaut (comme pour une erreur ordinaire) ; un test lui fait relancer l'erreur.
vi.mock('next/navigation', () => ({ redirect: mocks.redirect, unstable_rethrow: mocks.rethrow }));
vi.mock('next/headers', () => ({ headers: mocks.headers }));

/**
 * Tous les rôles du type `Role` (api.ts). Vérifié par `tsc --noEmit` : un rôle ajouté au type sans l'être ici
 * (ou l'inverse) est une erreur de typage ; le test « TOUS_ROLES » vérifie ensuite le tableau d'exécution.
 */
const ROLES_DU_TYPE: Record<Role, true> = {
  ADMIN: true,
  DIRECTION: true,
  DIRECTEUR_REGIONAL: true,
  CHEF_SECTEUR: true,
  COMMERCIAL: true,
  ADV: true,
  MARKETING: true,
};
const TOUS = Object.keys(ROLES_DU_TYPE) as Role[];

/** Encadrement tel que décidé : ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR. */
const ENCADREMENT_ATTENDU: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

const trie = (roles: readonly string[]): string[] => [...roles].sort();

function utilisateur(role: Role): Me {
  return {
    id: '00000000-0000-4000-8000-000000000001',
    username: `test.${role.toLowerCase()}`,
    displayName: `[TEST] ${role}`,
    email: null,
    role,
    idRepr: null,
    poste: null,
  };
}

/** GET /auth/me répond `status` (avec `corps` en JSON s'il est fourni) ; une nouvelle Response à chaque appel. */
function apiRepond(status: number, corps?: unknown): void {
  mocks.serverFetch.mockImplementation(
    async () => new Response(corps === undefined ? null : JSON.stringify(corps), { status }),
  );
}
/** Session valide : l'API renvoie cet utilisateur. */
const connecte = (me: unknown): void => apiRepond(200, me);
/** Pas de session : jeton absent, expiré ou refusé par l'API. */
const sansSession = (): void => apiRepond(401);

/** En-têtes de la requête courante (celui du middleware : le chemin demandé). */
function requeteSur(chemin: string | null): void {
  mocks.headers.mockResolvedValue(new Headers(chemin === null ? {} : { [ENTETE_CHEMIN]: chemin }));
}

beforeEach(() => {
  mocks.serverFetch.mockReset();
  mocks.headers.mockReset();
  mocks.redirect.mockReset();
  mocks.rethrow.mockReset();
  requeteSur(null);
  // Comme le vrai redirect() de Next : il ne rend jamais la main (il lève une erreur spéciale).
  mocks.redirect.mockImplementation((url: string) => {
    throw new Error(`NEXT_REDIRECT:${url}`);
  });
});

describe('ensembles de rôles', () => {
  it('ENCADREMENT = ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR', () => {
    expect(trie(ENCADREMENT)).toEqual(trie(ENCADREMENT_ATTENDU));
  });

  it('ENCADREMENT et TERRAIN sont disjoints', () => {
    const communs = ENCADREMENT.filter((r) => TERRAIN.includes(r));
    expect(communs).toEqual([]);
  });

  it('TOUS_ROLES = ENCADREMENT + TERRAIN + MARKETING, sans doublon', () => {
    expect(trie(TOUS_ROLES)).toEqual(trie([...ENCADREMENT, ...TERRAIN, 'MARKETING']));
    expect(new Set(TOUS_ROLES).size).toBe(TOUS_ROLES.length);
  });

  it('TOUS_ROLES couvre exactement les rôles du type Role', () => {
    expect(trie(TOUS_ROLES)).toEqual(trie(TOUS));
  });

  it('MARKETING n\'est ni encadrement ni terrain (il n\'a pas encore d\'espace défini)', () => {
    expect(ENCADREMENT).not.toContain('MARKETING');
    expect(TERRAIN).not.toContain('MARKETING');
  });

  it('COMMERCIAL est un rôle terrain, pas de l\'encadrement', () => {
    expect(TERRAIN).toContain('COMMERCIAL');
    expect(ENCADREMENT).not.toContain('COMMERCIAL');
  });
});

describe('estEncadrement', () => {
  it.each([
    ['ADMIN', true],
    ['DIRECTION', true],
    ['DIRECTEUR_REGIONAL', true],
    ['CHEF_SECTEUR', true],
    ['COMMERCIAL', false],
    ['ADV', false],
    ['MARKETING', false],
  ] as const)('%s : %s', (role, attendu) => {
    expect(estEncadrement(role)).toBe(attendu);
  });
});

describe('espaceDe', () => {
  it.each(ENCADREMENT_ATTENDU)('%s (encadrement) : espace « direction »', (role) => {
    expect(espaceDe(role)).toBe('direction');
  });

  it('COMMERCIAL : espace « promoteurs »', () => {
    expect(espaceDe('COMMERCIAL')).toBe('promoteurs');
  });

  it.each(TOUS)('%s : l\'espace est « promoteurs » ou « direction » (jamais indéfini)', (role) => {
    expect(['promoteurs', 'direction']).toContain(espaceDe(role));
  });

  // ADV et MARKETING : « à définir plus tard ». Ces deux tests décrivent l'ÉTAT ACTUEL du code, ils ne
  // fixent aucune règle métier : les modifier (ou les supprimer) dès que la décision sera prise.
  describe('état actuel PROVISOIRE (décision métier à venir pour ADV et MARKETING)', () => {
    it('ADV : « promoteurs » (classé TERRAIN pour l\'instant)', () => {
      expect(espaceDe('ADV')).toBe('promoteurs');
    });

    it("MARKETING : « promoteurs » (thème bleu, décision de l'utilisateur ; ce n'est ni encadrement ni terrain)", () => {
      expect(espaceDe('MARKETING')).toBe('promoteurs');
    });
  });
});

describe('lireSession (GET /auth/me)', () => {
  it('200 : connecté, avec l\'utilisateur renvoyé par l\'API', async () => {
    const me = utilisateur('CHEF_SECTEUR');
    connecte(me);

    await expect(lireSession()).resolves.toEqual({ etat: 'connecte', me });
    expect(mocks.serverFetch).toHaveBeenCalledWith('/auth/me');
  });

  it('200 : ne garde de l\'utilisateur que les champs de Me (ni photo, ni secteurId, ni dates)', async () => {
    const me = utilisateur('COMMERCIAL');
    connecte({ ...me, photo: { type: 'Buffer', data: [1, 2, 3] }, secteurId: 'secret', regionId: 'r', isActive: true });

    const session = await lireSession();

    expect(session).toEqual({ etat: 'connecte', me });
    expect(JSON.stringify(session)).not.toContain('secteurId');
    expect(JSON.stringify(session)).not.toContain('photo');
  });

  it('200 sans identifiant ni rôle : indisponible (anomalie de l\'API, pas une déconnexion)', async () => {
    connecte({ message: 'ok' });

    await expect(lireSession()).resolves.toEqual({ etat: 'indisponible' });
  });

  it.each([401, 403])('%i : session absente (jeton absent, expiré ou refusé)', async (statut) => {
    apiRepond(statut);

    await expect(lireSession()).resolves.toEqual({ etat: 'absente' });
  });

  it.each([500, 502, 503, 504, 404, 429])(
    '%i : API indisponible, la session n\'est PAS déclarée absente',
    async (statut) => {
      apiRepond(statut);

      await expect(lireSession()).resolves.toEqual({ etat: 'indisponible' });
    },
  );

  it('API injoignable (la requête échoue) : indisponible', async () => {
    mocks.serverFetch.mockRejectedValue(new TypeError('fetch failed'));

    await expect(lireSession()).resolves.toEqual({ etat: 'indisponible' });
  });

  it('une exception interne de Next (page dynamique, cookies) est RELANCÉE, jamais avalée en « indisponible »', async () => {
    // Sans cela, la génération statique (next build) prend la page pour une panne d'API et échoue.
    const signalDynamique = Object.assign(new Error('Dynamic server usage: cookies'), { digest: 'DYNAMIC_SERVER_USAGE' });
    mocks.serverFetch.mockRejectedValue(signalDynamique);
    mocks.rethrow.mockImplementation((e: unknown) => {
      throw e;
    });

    await expect(lireSession()).rejects.toBe(signalDynamique);
    expect(mocks.rethrow).toHaveBeenCalledWith(signalDynamique);
  });

  it('200 avec un corps illisible : indisponible (rien à conclure sur la session)', async () => {
    mocks.serverFetch.mockImplementation(async () => new Response('<html>passerelle</html>', { status: 200 }));

    await expect(lireSession()).resolves.toEqual({ etat: 'indisponible' });
  });
});

describe('urlLogin (retour sur la page demandée)', () => {
  it('sans chemin transmis par le middleware : /login', async () => {
    requeteSur(null);
    await expect(urlLogin()).resolves.toBe('/login');
  });

  it('avec un chemin : /login?from=<chemin encodé>, requête comprise', async () => {
    requeteSur('/rapports?semaine=2026-01-05');
    await expect(urlLogin()).resolves.toBe('/login?from=%2Frapports%3Fsemaine%3D2026-01-05');
  });

  it.each(['//evil.example', '/\\evil.example', 'https://evil.example', '/login', '/login?from=/x', '/a\tb'])(
    'chemin non sûr %j : ignoré, /login simple (jamais de redirection ouverte)',
    async (chemin) => {
      requeteSur(chemin);
      await expect(urlLogin()).resolves.toBe('/login');
    },
  );
});

describe('requireRole (garde de page)', () => {
  it('pas de session : redirige vers /login, la page ne se rend jamais', async () => {
    sansSession();

    await expect(requireRole(TOUS_ROLES)).rejects.toThrow('NEXT_REDIRECT:/login');

    expect(mocks.redirect).toHaveBeenCalledTimes(1);
    expect(mocks.redirect).toHaveBeenCalledWith('/login');
  });

  it('pas de session : la redirection ramène sur la page demandée (?from=)', async () => {
    sansSession();
    requeteSur('/rapports?semaine=2026-01-05');

    await expect(requireRole(TOUS_ROLES)).rejects.toThrow(
      'NEXT_REDIRECT:/login?from=%2Frapports%3Fsemaine%3D2026-01-05',
    );
  });

  it.each([500, 503])('API en erreur (%i) : pas de redirection vers /login, erreur « service indisponible »', async (statut) => {
    apiRepond(statut);

    await expect(requireRole(TOUS_ROLES)).rejects.toBeInstanceOf(ErreurServiceIndisponible);

    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('API injoignable : pas de redirection vers /login, erreur « service indisponible »', async () => {
    mocks.serverFetch.mockRejectedValue(new TypeError('fetch failed'));

    await expect(requireRole(TOUS_ROLES)).rejects.toBeInstanceOf(ErreurServiceIndisponible);

    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('rôle refusé : renvoie l\'écran « Accès refusé » avec l\'utilisateur, sans rediriger', async () => {
    const me = utilisateur('COMMERCIAL');
    connecte(me);

    const resultat = await requireRole(ENCADREMENT);

    expect(resultat.me).toEqual(me);
    expect(isValidElement(resultat.refuse)).toBe(true);
    expect(resultat.refuse?.type).toBe(AccesRefuse);
    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('rôle autorisé : renvoie l\'utilisateur et aucun écran de refus', async () => {
    const me = utilisateur('CHEF_SECTEUR');
    connecte(me);

    const resultat = await requireRole(ENCADREMENT);

    expect(resultat.me).toEqual(me);
    expect(resultat.refuse).toBeNull();
    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('liste de rôles vide : tout le monde est refusé (échec fermé)', async () => {
    connecte(utilisateur('ADMIN'));

    const resultat = await requireRole([]);

    expect(resultat.refuse).not.toBeNull();
  });

  it('rôle inconnu (API plus récente que le front) : refusé même avec TOUS_ROLES', async () => {
    connecte({ ...utilisateur('ADMIN'), role: 'SUPER_ADMIN' });

    const resultat = await requireRole(TOUS_ROLES);

    expect(resultat.refuse).not.toBeNull();
  });

  it('un seul appel à /auth/me par garde (chaque appel est une requête vers l\'API)', async () => {
    connecte(utilisateur('ADMIN'));

    await requireRole(TOUS_ROLES);

    expect(mocks.serverFetch).toHaveBeenCalledTimes(1);
  });

  it.each(TOUS)('%s face à ENCADREMENT : autorisé seulement s\'il en fait partie', async (role) => {
    connecte(utilisateur(role));

    const resultat = await requireRole(ENCADREMENT);

    expect(resultat.refuse === null).toBe(ENCADREMENT_ATTENDU.includes(role));
  });

  it.each(TOUS)('%s face à TOUS_ROLES : toujours autorisé', async (role) => {
    connecte(utilisateur(role));

    const resultat = await requireRole(TOUS_ROLES);

    expect(resultat.refuse).toBeNull();
  });
});

describe('exigerRole (garde de Server Action)', () => {
  it('pas de session : lève « Accès refusé » (une action ne redirige pas)', async () => {
    sansSession();

    await expect(exigerRole(TOUS_ROLES)).rejects.toThrow(/^Accès refusé$/);

    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('API indisponible : lève « service indisponible », pas un faux « Accès refusé »', async () => {
    apiRepond(503);

    const erreur = await exigerRole(TOUS_ROLES).catch((e: unknown) => e);

    expect(erreur).toBeInstanceOf(ErreurServiceIndisponible);
    expect((erreur as Error).message).not.toMatch(/Accès refusé/);
    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('rôle refusé : lève « Accès refusé »', async () => {
    connecte(utilisateur('COMMERCIAL'));

    await expect(exigerRole(ENCADREMENT)).rejects.toThrow(/^Accès refusé$/);

    expect(mocks.redirect).not.toHaveBeenCalled();
  });

  it('rôle autorisé : renvoie l\'utilisateur', async () => {
    const me = utilisateur('DIRECTION');
    connecte(me);

    await expect(exigerRole(['ADMIN', 'DIRECTION'])).resolves.toEqual(me);
  });

  it('liste de rôles vide : tout le monde est refusé (échec fermé)', async () => {
    connecte(utilisateur('ADMIN'));

    await expect(exigerRole([])).rejects.toThrow(/^Accès refusé$/);
  });

  it('rôle inconnu (API plus récente que le front) : refusé même avec TOUS_ROLES', async () => {
    connecte({ ...utilisateur('ADMIN'), role: 'SUPER_ADMIN' });

    await expect(exigerRole(TOUS_ROLES)).rejects.toThrow(/^Accès refusé$/);
  });

  it('le message est identique sans session et avec un mauvais rôle (aucune fuite d\'information)', async () => {
    sansSession();
    const sansSessionMessage = await exigerRole(['ADMIN']).catch((e: Error) => e.message);
    connecte(utilisateur('COMMERCIAL'));
    const mauvaisRole = await exigerRole(['ADMIN']).catch((e: Error) => e.message);

    expect(sansSessionMessage).toBe(mauvaisRole);
  });

  it.each(TOUS)('%s face à [ADMIN] : autorisé seulement s\'il est ADMIN', async (role) => {
    connecte(utilisateur(role));

    const issue = await exigerRole(['ADMIN']).then(
      () => 'autorise',
      () => 'refuse',
    );

    expect(issue).toBe(role === 'ADMIN' ? 'autorise' : 'refuse');
  });
});
