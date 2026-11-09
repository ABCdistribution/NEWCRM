import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  ApiIndisponibleError,
  getClient,
  getMe,
  normaliserPipeline,
  projeterMe,
  PROSPECT_STATUTS,
  serverFetch,
  type ProspectRow,
} from './api';

// Aucun réseau, aucune session : le cookie (`./session`), la navigation de Next et `fetch` sont remplacés.
// `redirect` / `notFound` se comportent comme dans Next : ils ne rendent jamais la main (ils lèvent).
const mocks = vi.hoisted(() => ({
  getToken: vi.fn(),
  redirect: vi.fn(),
  notFound: vi.fn(),
  fetch: vi.fn(),
}));
vi.mock('./session', () => ({ getToken: mocks.getToken, apiBase: () => 'http://api.test' }));
vi.mock('next/navigation', () => ({ redirect: mocks.redirect, notFound: mocks.notFound }));

const ID = '123e4567-e89b-42d3-a456-426614174000';

const json = (corps: unknown, status = 200) =>
  new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

beforeEach(() => {
  mocks.getToken.mockReset().mockResolvedValue('jwt-de-test');
  mocks.fetch.mockReset();
  mocks.redirect.mockReset().mockImplementation((url: string) => {
    throw new Error(`NEXT_REDIRECT:${url}`);
  });
  mocks.notFound.mockReset().mockImplementation(() => {
    throw new Error('NEXT_NOT_FOUND');
  });
  // Remplace le garde-fou « aucun réseau » (src/test/sans-reseau.ts) par un faux fetch : toujours aucun réseau.
  vi.stubGlobal('fetch', mocks.fetch);
});

/** Prospect minimal : seuls l'identité et le statut comptent pour le Kanban. */
const prospect = (id: string, statut: ProspectRow['statut']) => ({ id, statut, enseigne: `Enseigne ${id}` }) as ProspectRow;

describe('normaliserPipeline : GET /prospects/pipeline', () => {
  it('forme réelle de l\'API { etapes, scope } : une colonne par étape, « scope » n\'est pas une colonne', () => {
    const colonnes = normaliserPipeline({
      etapes: [
        { statut: 'NOUVEAU', total: 2, valeurPonderee: 1200, prospects: [prospect('a', 'NOUVEAU'), prospect('b', 'NOUVEAU')] },
        { statut: 'CONTACTE', total: 0, valeurPonderee: 0, prospects: [] },
        { statut: 'PROPOSITION', total: 0, valeurPonderee: 0, prospects: [] },
        { statut: 'VISITE', total: 0, valeurPonderee: 0, prospects: [] },
        { statut: 'NEGOCIATION', total: 1, valeurPonderee: 800, prospects: [prospect('c', 'NEGOCIATION')] },
        { statut: 'GAGNE', total: 3, valeurPonderee: 5000, prospects: [] },
        { statut: 'PERDU', total: 1, valeurPonderee: 0, prospects: [] },
      ],
      scope: { type: 'region' },
    });

    expect(colonnes.map((c) => c.statut)).toEqual(PROSPECT_STATUTS);
    expect(colonnes.map((c) => c.total)).toEqual([2, 0, 0, 0, 1, 3, 1]);
    expect(colonnes[0].valeurPonderee).toBe(1200);
    expect(colonnes[0].prospects.map((p) => p.id)).toEqual(['a', 'b']);
    expect(colonnes[4].prospects.map((p) => p.id)).toEqual(['c']);
    expect(colonnes.some((c) => (c.statut as string) === 'scope' || (c.statut as string) === 'etapes')).toBe(false);
  });

  it('étapes dans le désordre : toujours restituées dans l\'ordre du Kanban', () => {
    const colonnes = normaliserPipeline({
      etapes: [
        { statut: 'PERDU', total: 1, valeurPonderee: 0, prospects: [] },
        { statut: 'NOUVEAU', total: 4, valeurPonderee: 0, prospects: [] },
      ],
      scope: { type: 'global' },
    });

    expect(colonnes.map((c) => c.statut)).toEqual(PROSPECT_STATUTS);
    expect(colonnes[0].total).toBe(4);
    expect(colonnes[6].total).toBe(1);
  });

  it('un tableau de colonnes (ancienne forme) est accepté', () => {
    const colonnes = normaliserPipeline([{ statut: 'VISITE', total: 5, valeurPonderee: 10, prospects: [] }]);

    expect(colonnes).toHaveLength(7);
    expect(colonnes.find((c) => c.statut === 'VISITE')?.total).toBe(5);
  });

  it('{ colonnes: [...] } est accepté', () => {
    const colonnes = normaliserPipeline({ colonnes: [{ statut: 'GAGNE', total: 2, valeurPonderee: 0, prospects: [] }] });

    expect(colonnes.find((c) => c.statut === 'GAGNE')?.total).toBe(2);
  });

  it('une map { STATUT: {...} } est acceptée ; les clés qui ne sont pas des étapes sont ignorées', () => {
    const colonnes = normaliserPipeline({
      NOUVEAU: { prospects: [prospect('a', 'NOUVEAU')] },
      scope: { type: 'global' },
      AUTRE: { total: 99 },
    });

    expect(colonnes).toHaveLength(7);
    // total absent : déduit du nombre de prospects.
    expect(colonnes[0].total).toBe(1);
    expect(colonnes.reduce((somme, c) => somme + c.total, 0)).toBe(1);
  });

  it('étape absente, réponse vide ou illisible : 7 colonnes vides, jamais d\'erreur', () => {
    for (const reponse of [null, undefined, 'texte', 42, {}, [], { etapes: [] }, { etapes: null }]) {
      const colonnes = normaliserPipeline(reponse);
      expect(colonnes.map((c) => c.statut)).toEqual(PROSPECT_STATUTS);
      expect(colonnes.every((c) => c.total === 0 && c.valeurPonderee === 0 && c.prospects.length === 0)).toBe(true);
    }
  });

  it('colonne mal formée : valeurs neutres (prospects toujours un tableau)', () => {
    const colonnes = normaliserPipeline({
      etapes: [{ statut: 'NOUVEAU', total: 'beaucoup', valeurPonderee: null, prospects: null }, null, { statut: 'INCONNU' }],
    });

    expect(colonnes[0]).toEqual({ statut: 'NOUVEAU', total: 0, valeurPonderee: 0, prospects: [] });
    expect(colonnes).toHaveLength(7);
  });
});

describe('projeterMe : ne garder de /auth/me que les champs de Me', () => {
  const ligneBrute = {
    id: ID,
    username: 'jdupont',
    displayName: 'Jeanne Dupont',
    email: 'jeanne@exemple.test',
    role: 'DIRECTEUR_REGIONAL',
    idRepr: '068',
    poste: 'Directrice régionale',
    // Champs de la ligne Prisma qui ne doivent JAMAIS atteindre un composant client.
    photo: { type: 'Buffer', data: [255, 216, 255, 224] },
    isActive: true,
    secteurId: 'secteur-1',
    regionId: 'region-1',
    directeurId: null,
    createdAt: '2025-01-01T00:00:00.000Z',
    updatedAt: '2025-06-01T00:00:00.000Z',
  };

  it('supprime la photo et les champs internes', () => {
    const me = projeterMe(ligneBrute);

    expect(me).toEqual({
      id: ID,
      username: 'jdupont',
      displayName: 'Jeanne Dupont',
      email: 'jeanne@exemple.test',
      role: 'DIRECTEUR_REGIONAL',
      idRepr: '068',
      poste: 'Directrice régionale',
    });
    expect(Object.keys(me ?? {}).sort()).toEqual(['displayName', 'email', 'id', 'idRepr', 'poste', 'role', 'username']);
  });

  it('champs optionnels absents : null', () => {
    const me = projeterMe({ id: ID, role: 'COMMERCIAL', username: 'a', displayName: 'A' });

    expect(me).toMatchObject({ email: null, idRepr: null, poste: null });
  });

  it('rôle inconnu conservé (c\'est requireRole qui le refuse)', () => {
    expect(projeterMe({ ...ligneBrute, role: 'SUPER_ADMIN' })?.role).toBe('SUPER_ADMIN');
  });

  it.each(
    [null, undefined, 'x', 3, [], {}, { id: ID }, { role: 'ADMIN' }, { id: 12, role: 'ADMIN' }].map((r) => [r]),
  )(
    'réponse inexploitable (%j) : null',
    (reponse) => {
      expect(projeterMe(reponse)).toBeNull();
    },
  );
});

describe('getMe : session absente ≠ API indisponible', () => {
  it('pas de cookie : null, sans appeler l\'API', async () => {
    mocks.getToken.mockResolvedValue(null);

    await expect(getMe()).resolves.toBeNull();
    expect(mocks.fetch).not.toHaveBeenCalled();
  });

  it.each([401, 403])('HTTP %s : session expirée, null', async (status) => {
    mocks.fetch.mockResolvedValue(json({ message: 'Unauthorized' }, status));

    await expect(getMe()).resolves.toBeNull();
  });

  it.each([500, 502, 503, 504, 429])('HTTP %s : lève ApiIndisponibleError (ce n\'est pas une déconnexion)', async (status) => {
    mocks.fetch.mockResolvedValue(json({ message: 'KO' }, status));

    await expect(getMe()).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('API injoignable (fetch failed) : ApiIndisponibleError', async () => {
    mocks.fetch.mockRejectedValue(new TypeError('fetch failed'));

    await expect(getMe()).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('délai dépassé : ApiIndisponibleError', async () => {
    mocks.fetch.mockRejectedValue(new DOMException('The operation timed out.', 'TimeoutError'));

    await expect(getMe()).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('corps illisible malgré un 200 : ApiIndisponibleError', async () => {
    mocks.fetch.mockResolvedValue(new Response('<html>proxy</html>', { status: 200 }));

    await expect(getMe()).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('session valide : renvoie l\'utilisateur projeté, jeton en Bearer, avec un délai d\'attente', async () => {
    mocks.fetch.mockResolvedValue(json({ id: ID, username: 'u', displayName: 'U', role: 'ADMIN', photo: { type: 'Buffer', data: [1] } }));

    const me = await getMe();

    expect(me).toMatchObject({ id: ID, role: 'ADMIN' });
    expect(me).not.toHaveProperty('photo');
    const [url, init] = mocks.fetch.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('http://api.test/auth/me');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer jwt-de-test');
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('un message d\'erreur lisible par l\'utilisateur, en français', () => {
    expect(new ApiIndisponibleError().message).toBe('Service momentanément indisponible, réessayez dans un instant.');
  });
});

describe('serverFetch : délai d\'attente', () => {
  it('toute requête porte un signal d\'annulation', async () => {
    mocks.fetch.mockResolvedValue(json({}));

    await serverFetch('/clients');

    const init = mocks.fetch.mock.calls[0][1] as RequestInit;
    expect(init.signal).toBeInstanceOf(AbortSignal);
    expect(init.signal?.aborted).toBe(false);
  });

  it('un signal fourni par l\'appelant est respecté', async () => {
    mocks.fetch.mockResolvedValue(json({}));
    const controleur = new AbortController();

    await serverFetch('/clients', { signal: controleur.signal });

    expect((mocks.fetch.mock.calls[0][1] as RequestInit).signal).toBe(controleur.signal);
  });

  it('`timeoutMs` n\'est pas transmis à fetch', async () => {
    mocks.fetch.mockResolvedValue(json({}));

    await serverFetch('/clients', { timeoutMs: 5000 });

    expect(mocks.fetch.mock.calls[0][1]).not.toHaveProperty('timeoutMs');
  });

  it('la synchro AD (traitement synchrone long) a un délai plus large que le délai par défaut', async () => {
    const delais: number[] = [];
    const timeout = vi.spyOn(AbortSignal, 'timeout').mockImplementation((ms: number) => {
      delais.push(ms);
      return new AbortController().signal;
    });
    mocks.fetch.mockResolvedValue(json({}));

    await serverFetch('/clients');
    await serverFetch('/sync/ad', { method: 'POST' });
    timeout.mockRestore();

    expect(delais).toHaveLength(2);
    expect(delais[1]).toBeGreaterThan(delais[0]);
  });

  it('une réponse HTTP en erreur est renvoyée telle quelle (c\'est à l\'appelant de lire res.ok)', async () => {
    mocks.fetch.mockResolvedValue(json({ message: 'KO' }, 500));

    const res = await serverFetch('/clients');

    expect(res.status).toBe(500);
  });

  it('une erreur qui n\'est pas une panne réseau est relancée telle quelle', async () => {
    const bug = new Error('autre erreur');
    mocks.fetch.mockRejectedValue(bug);

    await expect(serverFetch('/clients')).rejects.toBe(bug);
  });
});

describe('getters de détail : 404 / 401 / 5xx distingués', () => {
  it('200 : la ressource', async () => {
    mocks.fetch.mockResolvedValue(json({ id: ID, enseigne: 'Test' }));

    await expect(getClient(ID)).resolves.toMatchObject({ id: ID });
  });

  it.each([404, 403])('HTTP %s : null (la page affichera un 404)', async (status) => {
    mocks.fetch.mockResolvedValue(json({ message: 'introuvable' }, status));

    await expect(getClient(ID)).resolves.toBeNull();
  });

  it('401 : redirection vers /login (et non un faux 404)', async () => {
    mocks.fetch.mockResolvedValue(json({ message: 'Unauthorized' }, 401));

    await expect(getClient(ID)).rejects.toThrow('NEXT_REDIRECT:/login');
    expect(mocks.redirect).toHaveBeenCalledWith('/login');
  });

  it.each([500, 503])('HTTP %s : ApiIndisponibleError (et non un faux 404)', async (status) => {
    mocks.fetch.mockResolvedValue(json({ message: 'KO' }, status));

    await expect(getClient(ID)).rejects.toBeInstanceOf(ApiIndisponibleError);
    expect(mocks.notFound).not.toHaveBeenCalled();
  });

  it('API injoignable : ApiIndisponibleError', async () => {
    mocks.fetch.mockRejectedValue(new TypeError('fetch failed'));

    await expect(getClient(ID)).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('identifiant invalide : 404 sans aucun appel à l\'API', async () => {
    await expect(getClient('../admin')).rejects.toThrow('NEXT_NOT_FOUND');
    expect(mocks.fetch).not.toHaveBeenCalled();
  });
});
