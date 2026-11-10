import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ID_EXEMPLE, ID_EXEMPLE_2 } from '@/test/pages-reelles';
import { GET } from '../app/pj/[id]/[pjId]/route';
import { ENCADREMENT, ErreurServiceIndisponible, type Role } from './roles';

// Le relais /pj : ni session ni réseau réels. `exigerRole` (garde) et `serverFetch` (API) sont remplacés ;
// ENCADREMENT et ErreurServiceIndisponible sont les vrais.
const mocks = vi.hoisted(() => ({ serverFetch: vi.fn(), exigerRole: vi.fn() }));
vi.mock('@/lib/api', () => ({ serverFetch: mocks.serverFetch }));
vi.mock('@/lib/roles', async (importOriginal) => ({
  ...(await importOriginal<typeof import('./roles')>()),
  exigerRole: mocks.exigerRole,
}));

const appeler = (id: string, pjId: string) =>
  GET(new Request(`http://localhost:3001/pj/${id}/${pjId}`), { params: Promise.resolve({ id, pjId }) });

beforeEach(() => {
  mocks.serverFetch.mockReset();
  mocks.exigerRole.mockReset();
  mocks.exigerRole.mockResolvedValue({ role: 'ADMIN' });
  mocks.serverFetch.mockImplementation(
    async () => new Response('contenu', { status: 200, headers: { 'content-type': 'application/pdf' } }),
  );
});

describe('GET /pj/[id]/[pjId] : garde de rôle', () => {
  it('exige un rôle de l\'encadrement (comme la fiche prospect et les Server Actions)', async () => {
    await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(mocks.exigerRole).toHaveBeenCalledTimes(1);
    const roles = mocks.exigerRole.mock.calls[0][0] as readonly Role[];
    expect([...roles].sort()).toEqual([...ENCADREMENT].sort());
  });

  it('rôle refusé (par exemple COMMERCIAL) ou session absente : 404, l\'API n\'est jamais appelée', async () => {
    mocks.exigerRole.mockRejectedValue(new Error('Accès refusé'));

    const res = await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(res.status).toBe(404);
    expect(await res.text()).toBe('');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('API indisponible au moment de la garde : 503 (et non un faux refus), l\'API n\'est pas appelée', async () => {
    mocks.exigerRole.mockRejectedValue(new ErreurServiceIndisponible());

    const res = await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(res.status).toBe(503);
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('identifiants non UUID : 404 avant toute garde et tout appel', async () => {
    const res = await appeler('../../users', ID_EXEMPLE_2);

    expect(res.status).toBe(404);
    expect(mocks.exigerRole).not.toHaveBeenCalled();
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });
});

describe('GET /pj/[id]/[pjId] : rôle autorisé', () => {
  it('relaie le fichier de l\'API en téléchargement forcé, sans mise en cache', async () => {
    const res = await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(mocks.serverFetch).toHaveBeenCalledWith(`/prospects/${ID_EXEMPLE}/pieces-jointes/${ID_EXEMPLE_2}`);
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toBe('application/pdf');
    expect(res.headers.get('content-disposition')).toBe('attachment');
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
    expect(res.headers.get('cache-control')).toBe('private, no-store');
  });

  it('le statut d\'erreur de l\'API (404, 403…) est relayé sans corps', async () => {
    mocks.serverFetch.mockImplementation(async () => new Response('{"message":"x"}', { status: 403 }));

    const res = await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(res.status).toBe(403);
    expect(await res.text()).toBe('');
  });

  it('type inconnu : servi en octet-stream (jamais affiché en ligne)', async () => {
    mocks.serverFetch.mockImplementation(
      async () => new Response('<script>', { status: 200, headers: { 'content-type': 'text/html' } }),
    );

    const res = await appeler(ID_EXEMPLE, ID_EXEMPLE_2);

    expect(res.headers.get('content-type')).toBe('application/octet-stream');
  });
});
