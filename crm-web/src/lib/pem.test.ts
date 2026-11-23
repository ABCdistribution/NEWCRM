import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  CLASSES_PEM,
  ROLES_FREQUENCES_PEM,
  ROLES_LECTURE_PROPOSITIONS_PEM,
  ROLES_SUIVI_PEM,
  formaterJourPem,
  frequenceDuMagasin,
  libelleSemaines,
  lireFrequences,
  lireProposition,
  lirePropositionOuverte,
  lireReponseFrequences,
  semainesValides,
  type FrequencesPem,
} from './pem';
import { changerSuiviPem, enregistrerFrequencesPem } from './pem-actions';

// Aucun réseau, aucune session : `serverFetch`, la garde de rôle et le cache de Next sont remplacés.
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

const ID = '123e4567-e89b-42d3-a456-426614174000';
const form = (champs: Record<string, string>) => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(champs)) fd.set(k, v);
  return fd;
};
const json = (corps: unknown, status = 200) =>
  new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

const FREQUENCES: FrequencesPem = {
  classes: CLASSES_PEM.map((niveauClass, i) => ({ niveauClass, semaines: 2 + i })),
  sansClasse: 4,
};
const champsFrequences = (plus: Record<string, string> = {}) => ({
  ...Object.fromEntries(CLASSES_PEM.map((c, i) => [`semaines-${c}`, String(2 + i)])),
  ...plus,
});

const PROPOSITION = {
  id: ID,
  dateProposee: '2026-12-02',
  statut: 'PROPOSEE',
  nbReports: 0,
  obligatoire: false,
  reportsRestants: 3,
  promoteur: { id: 'p1', displayName: 'Léa Martin' },
};

beforeEach(() => {
  mocks.serverFetch.mockReset().mockResolvedValue(json({}));
  mocks.exigerRole.mockReset().mockResolvedValue({ role: 'ADMIN' });
  mocks.revalidatePath.mockReset();
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('rôles', () => {
  it('le suivi PEM se gère par ADMIN, DIRECTION et DIRECTEUR_REGIONAL ; les fréquences par ADMIN et DIRECTION', () => {
    expect([...ROLES_SUIVI_PEM]).toEqual(['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL']);
    expect([...ROLES_FREQUENCES_PEM]).toEqual(['ADMIN', 'DIRECTION']);
  });
});

describe('validation', () => {
  it('semaines : entier de 1 à 52', () => {
    expect(semainesValides('1')).toBe(1);
    expect(semainesValides(' 52 ')).toBe(52);
    expect(semainesValides(8)).toBe(8);
    for (const v of ['0', '53', '-1', '2.5', '', 'abc', '1e1', null, undefined, NaN, 2.5, '999']) {
      expect(semainesValides(v)).toBeNull();
    }
  });

  it('libellé au pluriel', () => {
    expect(libelleSemaines(1)).toBe('1 semaine');
    expect(libelleSemaines(4)).toBe('4 semaines');
  });

  it('lireFrequences : 7 classes obligatoires, message précisant la classe fautive', () => {
    const valeurs = champsFrequences();
    const ok = lireFrequences((n) => valeurs[n] ?? '');
    expect(ok.erreur).toBeNull();
    expect(ok.classes).toHaveLength(7);
    expect(ok.classes?.[0]).toEqual({ niveauClass: 'A', semaines: 2 });
    expect(ok.classes?.[6]).toEqual({ niveauClass: 'G', semaines: 8 });

    const mauvais = champsFrequences({ 'semaines-C': '60' });
    const ko = lireFrequences((n) => mauvais[n] ?? '');
    expect(ko.classes).toBeNull();
    expect(ko.erreur).toContain('Classe C');

    const manquant = champsFrequences();
    delete manquant['semaines-G'];
    expect(lireFrequences((n) => manquant[n] ?? '').erreur).toContain('Classe G');
  });

  it('réponse des fréquences : ordonnée A→G, ou rejetée si incomplète ou malformée', () => {
    const melange = { classes: [...FREQUENCES.classes].reverse(), sansClasse: 4 };
    expect(lireReponseFrequences(melange)).toEqual(FREQUENCES);
    expect(lireReponseFrequences({ classes: FREQUENCES.classes.slice(1), sansClasse: 4 })).toBeNull();
    expect(lireReponseFrequences({ classes: [{ niveauClass: 'Z', semaines: 3 }], sansClasse: 4 })).toBeNull();
    expect(lireReponseFrequences({ classes: FREQUENCES.classes })).toBeNull();
    expect(lireReponseFrequences(null)).toBeNull();
    expect(lireReponseFrequences([])).toBeNull();
  });

  it('fréquence d’un magasin : celle de sa classe, « sans classe » sinon', () => {
    expect(frequenceDuMagasin(FREQUENCES, 'A')).toBe(2);
    expect(frequenceDuMagasin(FREQUENCES, 'G')).toBe(8);
    expect(frequenceDuMagasin(FREQUENCES, null)).toBe(4);
    expect(frequenceDuMagasin(FREQUENCES, 'Z')).toBe(4);
  });

  it('proposition : champs contrôlés, jour tronqué à yyyy-mm-dd', () => {
    expect(lireProposition({ ...PROPOSITION, dateProposee: '2026-12-02T00:00:00.000Z' })).toMatchObject({
      id: ID,
      dateProposee: '2026-12-02',
      promoteur: { displayName: 'Léa Martin' },
    });
    expect(lireProposition(null)).toBeNull();
    expect(lireProposition({ id: ID, dateProposee: 'bientôt' })).toBeNull();
    expect(lireProposition({ ...PROPOSITION, promoteur: undefined })?.promoteur).toBeNull();
  });

  it('proposition ouverte d’un magasin : la première de la liste, rien si vide ou inattendu', () => {
    expect(lirePropositionOuverte({ data: [PROPOSITION], total: 1 })).toMatchObject({ id: ID });
    expect(lirePropositionOuverte({ data: [{ ...PROPOSITION, statut: 'ANNULEE' }, PROPOSITION] })?.id).toBe(ID);
    expect(lirePropositionOuverte({ data: [{ ...PROPOSITION, statut: 'ANNULEE' }] })).toBeNull();
    expect(lirePropositionOuverte({ data: [] })).toBeNull();
    expect(lirePropositionOuverte([PROPOSITION])).toBeNull();
    expect(lirePropositionOuverte(null)).toBeNull();
  });

  it('lecture des propositions : mêmes rôles que l’API', () => {
    expect(ROLES_LECTURE_PROPOSITIONS_PEM).toEqual(['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'COMMERCIAL']);
  });

  it('jour en français, sans décalage de fuseau', () => {
    expect(formaterJourPem('2026-12-02')).toBe('mercredi 2 décembre 2026');
    expect(formaterJourPem('nimporte quoi')).toBe('nimporte quoi');
  });
});

describe('changerSuiviPem', () => {
  it('exige les rôles ADMIN, DIRECTION et DIRECTEUR_REGIONAL, et refuse sans appeler l’API', async () => {
    await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }));
    expect(mocks.exigerRole).toHaveBeenCalledWith(['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL']);

    mocks.serverFetch.mockClear();
    mocks.exigerRole.mockRejectedValue(new Error('refus'));
    const r = await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }));
    expect(r.error).toEqual(expect.any(String));
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('refuse un identifiant ou une valeur invalide sans appeler l’API', async () => {
    expect((await changerSuiviPem(form({ clientId: '../x', suiviPem: 'true' }))).error).toBe('Client invalide.');
    expect((await changerSuiviPem(form({ clientId: ID, suiviPem: 'oui' }))).error).toBe('Valeur invalide.');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('activation : PATCH sur le chemin encodé, renvoie la proposition et revalide la fiche', async () => {
    mocks.serverFetch.mockResolvedValue(json({ id: ID, suiviPem: true, proposition: PROPOSITION }));
    const r = await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }));
    expect(mocks.serverFetch).toHaveBeenCalledWith(
      `/clients/${ID}/suivi-pem`,
      expect.objectContaining({ method: 'PATCH', body: JSON.stringify({ suiviPem: true }) }),
    );
    expect(r).toMatchObject({ error: null, suiviPem: true, proposition: { dateProposee: '2026-12-02' } });
    expect(mocks.revalidatePath).toHaveBeenCalledWith(`/clients/${ID}`);
  });

  it('activation sans proposition à faire, et désactivation : aucune proposition renvoyée', async () => {
    mocks.serverFetch.mockResolvedValue(json({ id: ID, suiviPem: true, proposition: null }));
    expect(await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }))).toEqual({
      error: null,
      suiviPem: true,
      proposition: null,
    });
    mocks.serverFetch.mockResolvedValue(json({ id: ID, suiviPem: false, proposition: PROPOSITION }));
    expect(await changerSuiviPem(form({ clientId: ID, suiviPem: 'false' }))).toEqual({
      error: null,
      suiviPem: false,
      proposition: null,
    });
  });

  it('403 hors région : le message de l’API est affiché tel quel, sans revalidation', async () => {
    mocks.serverFetch.mockResolvedValue(json({ message: "Ce magasin n'est pas dans votre région" }, 403));
    const r = await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }));
    expect(r).toEqual({ error: "Ce magasin n'est pas dans votre région" });
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it('erreur serveur masquée, API injoignable signalée', async () => {
    mocks.serverFetch.mockResolvedValue(json({ message: 'détail interne' }, 500));
    const r = await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }));
    expect(r.error).toContain('500');
    expect(r.error).not.toContain('interne');
    mocks.serverFetch.mockRejectedValue(new Error('réseau'));
    expect((await changerSuiviPem(form({ clientId: ID, suiviPem: 'true' }))).error).toBe("Impossible de joindre l'API.");
  });
});

describe('enregistrerFrequencesPem', () => {
  it('exige ADMIN ou DIRECTION, et refuse sans appeler l’API', async () => {
    expect(await enregistrerFrequencesPem(form(champsFrequences()))).toBeNull();
    expect(mocks.exigerRole).toHaveBeenCalledWith(['ADMIN', 'DIRECTION']);

    mocks.serverFetch.mockClear();
    mocks.exigerRole.mockRejectedValue(new Error('refus'));
    expect(typeof (await enregistrerFrequencesPem(form(champsFrequences())))).toBe('string');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('valide avant d’appeler l’API', async () => {
    expect(await enregistrerFrequencesPem(form(champsFrequences({ 'semaines-B': '0' })))).toContain('Classe B');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('PUT des 7 classes, revalide /admin', async () => {
    expect(await enregistrerFrequencesPem(form(champsFrequences()))).toBeNull();
    const [chemin, options] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe('/pem/frequences');
    expect(options.method).toBe('PUT');
    const corps = JSON.parse(options.body);
    expect(corps.classes).toHaveLength(7);
    expect(corps.classes[1]).toEqual({ niveauClass: 'B', semaines: 3 });
    expect(mocks.revalidatePath).toHaveBeenCalledWith('/admin');
  });

  it('relaye l’erreur de l’API sans revalider', async () => {
    mocks.serverFetch.mockResolvedValue(json({ message: 'La fréquence ne doit pas dépasser 52 semaines' }, 400));
    expect(await enregistrerFrequencesPem(form(champsFrequences()))).toBe('La fréquence ne doit pas dépasser 52 semaines');
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });
});
