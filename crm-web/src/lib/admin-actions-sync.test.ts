import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiIndisponibleError } from './api';
import { syncAd } from './admin-actions';

// Aucun réseau, aucune session : `serverFetch`, la garde de rôle et le cache de Next sont remplacés.
// L'erreur `ApiIndisponibleError` est la vraie (c'est elle que `serverFetch` lève sur un délai dépassé).
const mocks = vi.hoisted(() => ({
  serverFetch: vi.fn(),
  exigerRole: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock('./session', () => ({ getToken: vi.fn(), apiBase: () => 'http://api.test' }));
vi.mock('next/navigation', () => ({ redirect: vi.fn(), notFound: vi.fn() }));
vi.mock('next/cache', () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock('./roles', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./roles')>()),
  exigerRole: mocks.exigerRole,
}));
vi.mock('./api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./api')>()),
  serverFetch: mocks.serverFetch,
}));

const json = (corps: unknown, status = 200) =>
  new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

const STATS = {
  lus: 64,
  crees: 3,
  maj: 61,
  photos: 60,
  directeursLies: 58,
  sansRegion: [],
  sansManager: [],
  conflitsIdRepr: [],
  tronque: false,
};

const etat = { error: null, ok: false } as const;

beforeEach(() => {
  mocks.serverFetch.mockReset();
  mocks.exigerRole.mockReset().mockResolvedValue({ role: 'ADMIN' });
  mocks.revalidatePath.mockReset();
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('syncAd : synchronisation AD (action serveur)', () => {
  it('succès : renvoie le compte rendu et rafraîchit /admin', async () => {
    mocks.serverFetch.mockResolvedValue(json(STATS));
    const r = await syncAd(etat, new FormData());
    expect(r).toEqual({ error: null, ok: true, stats: STATS });
    expect(mocks.serverFetch).toHaveBeenCalledWith('/sync/ad', { method: 'POST' });
    expect(mocks.revalidatePath).toHaveBeenCalledWith('/admin');
  });

  it('refuse sans appeler l’API quand le rôle ne convient pas', async () => {
    mocks.exigerRole.mockRejectedValue(new Error('Accès refusé'));
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/Accès refusé/);
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('délai de 180 s dépassé : dit que la synchro a pu aboutir (et non « API injoignable »)', async () => {
    const delai = Object.assign(new Error('The operation was aborted due to timeout'), { name: 'TimeoutError' });
    mocks.serverFetch.mockRejectedValue(new ApiIndisponibleError({ cause: delai }));
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/n'a pas répondu en 3 minutes/);
    expect(r.error).toMatch(/a pu aboutir/);
    expect(r.error).not.toMatch(/Impossible de joindre/);
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it('autre panne de transport : API injoignable', async () => {
    mocks.serverFetch.mockRejectedValue(new ApiIndisponibleError({ cause: new TypeError('fetch failed') }));
    const r = await syncAd(etat, new FormData());
    expect(r).toEqual({ error: "Impossible de joindre l'API.", ok: false });
  });

  it('503 de l’API : annuaire AD injoignable, rien n’a été modifié', async () => {
    mocks.serverFetch.mockResolvedValue(json({ statusCode: 503, message: 'Annuaire Active Directory (LDAP) injoignable' }, 503));
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/Active Directory est injoignable/);
    expect(r.error).toMatch(/Rien n'a été modifié/);
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it('409 (synchro déjà en cours) : relaie le message français de l’API', async () => {
    mocks.serverFetch.mockResolvedValue(
      json({ statusCode: 409, message: 'Une synchronisation AD est déjà en cours : attendez sa fin avant de la relancer.' }, 409),
    );
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/déjà en cours/);
  });

  it('autre 5xx : texte fixe, le message de l’API n’est pas relayé', async () => {
    mocks.serverFetch.mockResolvedValue(json({ statusCode: 500, message: 'relation "users" does not exist' }, 500));
    const r = await syncAd(etat, new FormData());
    expect(r.error).toMatch(/code 500/);
    expect(r.error).not.toMatch(/relation/);
  });

  it('401 : session expirée', async () => {
    mocks.serverFetch.mockResolvedValue(json({ statusCode: 401, message: 'Unauthorized' }, 401));
    const r = await syncAd(etat, new FormData());
    expect(r.error).toMatch(/Session expirée/);
  });

  it('2xx mais compte rendu illisible : ne jette pas, invite à vérifier', async () => {
    mocks.serverFetch.mockResolvedValue(new Response('<html>proxy</html>', { status: 200 }));
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/illisible/);
  });

  it('relaie l’avertissement « lecture tronquée » du compte rendu', async () => {
    mocks.serverFetch.mockResolvedValue(json({ ...STATS, tronque: true }));
    const r = await syncAd(etat, new FormData());
    expect(r.ok).toBe(true);
    expect(r.stats?.tronque).toBe(true);
  });
});
