import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  controlerLibelle,
  directionValide,
  LONGUEUR_QUESTION,
  LONGUEUR_RAISON,
  typeQuestionValide,
} from './visites-admin';
import {
  ajouterQuestion,
  ajouterRaison,
  deplacerQuestion,
  deplacerRaison,
  modifierQuestion,
  modifierRaison,
  supprimerQuestion,
  supprimerRaison,
} from './visites-admin-actions';
import { ONGLETS, ongletValide } from '@/components/admin/onglets';

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
const ok = () => new Response('{}', { status: 200 });

const form = (champs: Record<string, string>) => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(champs)) fd.set(k, v);
  return fd;
};

beforeEach(() => {
  mocks.serverFetch.mockReset().mockResolvedValue(ok());
  mocks.exigerRole.mockReset().mockResolvedValue({ role: 'ADMIN' });
  mocks.revalidatePath.mockReset();
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('validation', () => {
  it('types de question', () => {
    for (const t of ['CASE_A_COCHER', 'TEXTE', 'NOMBRE', 'NOTE_1_5']) expect(typeQuestionValide(t)).toBe(true);
    for (const t of ['', 'texte', 'AUTRE']) expect(typeQuestionValide(t)).toBe(false);
  });

  it('direction', () => {
    expect(directionValide('haut')).toBe(true);
    expect(directionValide('bas')).toBe(true);
    expect(directionValide('gauche')).toBe(false);
  });

  it('libellé : nettoyé, vide et trop long refusés', () => {
    expect(controlerLibelle('  Bonjour  ', 10)).toEqual({ libelle: 'Bonjour', erreur: null });
    expect(controlerLibelle('   ', 10).erreur).toMatch(/obligatoire/);
    expect(controlerLibelle('x'.repeat(11), 10).erreur).toMatch(/10 caractères/);
  });
});

describe('onglet Visites', () => {
  it('existe dans la console', () => {
    expect(ONGLETS.some((o) => o.id === 'visites' && !o.bientot)).toBe(true);
    expect(ongletValide('visites')).toBe('visites');
  });
});

describe('gardes : ADMIN seul, aucun appel d’API si refusé', () => {
  const appels: [string, () => Promise<string | null>][] = [
    ['ajouterQuestion', () => ajouterQuestion(form({ libelle: 'Q' }))],
    ['modifierQuestion', () => modifierQuestion(form({ id: ID, actif: 'false' }))],
    ['deplacerQuestion', () => deplacerQuestion(form({ id: ID, direction: 'haut' }))],
    ['supprimerQuestion', () => supprimerQuestion(form({ id: ID }))],
    ['ajouterRaison', () => ajouterRaison(form({ libelle: 'R' }))],
    ['modifierRaison', () => modifierRaison(form({ id: ID, actif: 'false' }))],
    ['deplacerRaison', () => deplacerRaison(form({ id: ID, direction: 'bas' }))],
    ['supprimerRaison', () => supprimerRaison(form({ id: ID }))],
  ];

  it.each(appels)('%s exige le rôle ADMIN', async (_nom, appel) => {
    mocks.exigerRole.mockRejectedValue(new Error('Accès refusé'));
    expect(await appel()).toMatch(/Accès refusé|réservée/);
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it.each(appels)('%s appelle exigerRole([ADMIN]) puis rafraîchit /admin', async (_nom, appel) => {
    expect(await appel()).toBeNull();
    expect(mocks.exigerRole).toHaveBeenCalledWith(['ADMIN']);
    expect(mocks.revalidatePath).toHaveBeenCalledWith('/admin');
  });
});

describe('questionnaire', () => {
  it('ajout : POST avec type et obligatoire', async () => {
    await ajouterQuestion(form({ libelle: ' PLV posée ? ', type: 'NOTE_1_5', obligatoire: 'on' }));
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe('/questionnaire/questions');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body)).toEqual({ libelle: 'PLV posée ?', type: 'NOTE_1_5', obligatoire: true });
  });

  it('ajout : type par défaut case à cocher, non obligatoire', async () => {
    await ajouterQuestion(form({ libelle: 'Q' }));
    expect(JSON.parse(mocks.serverFetch.mock.calls[0][1].body)).toEqual({
      libelle: 'Q',
      type: 'CASE_A_COCHER',
      obligatoire: false,
    });
  });

  it('refuse libellé vide, trop long et type inconnu sans appeler l’API', async () => {
    expect(await ajouterQuestion(form({ libelle: '  ' }))).toMatch(/obligatoire/);
    expect(await ajouterQuestion(form({ libelle: 'x'.repeat(LONGUEUR_QUESTION + 1) }))).toMatch(/caractères/);
    expect(await ajouterQuestion(form({ libelle: 'Q', type: 'AUTRE' }))).toMatch(/Type/);
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('modification : ne transmet que les champs présents', async () => {
    await modifierQuestion(form({ id: ID, actif: 'false' }));
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe(`/questionnaire/questions/${ID}`);
    expect(init.method).toBe('PATCH');
    expect(JSON.parse(init.body)).toEqual({ actif: false });
  });

  it('modification : obligatoire décoché transmis à false', async () => {
    await modifierQuestion(form({ id: ID, libelle: 'Q', type: 'TEXTE', obligatoire: 'false' }));
    expect(JSON.parse(mocks.serverFetch.mock.calls[0][1].body)).toEqual({ libelle: 'Q', type: 'TEXTE', obligatoire: false });
  });

  it('refuse un id non UUID (aucun appel, pas de traversée de chemin)', async () => {
    for (const id of ['', 'abc', '../users', `${ID}/../x`]) {
      expect(await supprimerQuestion(form({ id }))).toBe('Élément invalide.');
      expect(await deplacerQuestion(form({ id, direction: 'haut' }))).toBe('Élément invalide.');
      expect(await modifierQuestion(form({ id, actif: 'true' }))).toBe('Élément invalide.');
    }
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('déplacement : direction vérifiée', async () => {
    expect(await deplacerQuestion(form({ id: ID, direction: 'milieu' }))).toBe('Direction invalide.');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
    await deplacerQuestion(form({ id: ID, direction: 'bas' }));
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe(`/questionnaire/questions/${ID}/deplacer`);
    expect(JSON.parse(init.body)).toEqual({ direction: 'bas' });
  });

  it('suppression : DELETE', async () => {
    await supprimerQuestion(form({ id: ID }));
    expect(mocks.serverFetch).toHaveBeenCalledWith(`/questionnaire/questions/${ID}`, { method: 'DELETE' });
  });
});

describe('raisons d’absence de commande', () => {
  it('ajout : POST du libellé nettoyé', async () => {
    await ajouterRaison(form({ libelle: '  Stock suffisant ' }));
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe('/raisons-absence-commande');
    expect(JSON.parse(init.body)).toEqual({ libelle: 'Stock suffisant' });
  });

  it('refuse libellé vide ou trop long', async () => {
    expect(await ajouterRaison(form({ libelle: '' }))).toMatch(/obligatoire/);
    expect(await modifierRaison(form({ id: ID, libelle: 'x'.repeat(LONGUEUR_RAISON + 1) }))).toMatch(/caractères/);
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('renommer et activer : PATCH', async () => {
    await modifierRaison(form({ id: ID, libelle: 'Autre', actif: 'true' }));
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe(`/raisons-absence-commande/${ID}`);
    expect(init.method).toBe('PATCH');
    expect(JSON.parse(init.body)).toEqual({ libelle: 'Autre', actif: true });
  });

  it('refuse une modification vide et un id invalide', async () => {
    expect(await modifierRaison(form({ id: ID }))).toMatch(/Aucune modification/);
    expect(await supprimerRaison(form({ id: 'x' }))).toBe('Élément invalide.');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('déplacement et suppression', async () => {
    await deplacerRaison(form({ id: ID, direction: 'haut' }));
    expect(mocks.serverFetch.mock.calls[0][0]).toBe(`/raisons-absence-commande/${ID}/deplacer`);
    await supprimerRaison(form({ id: ID }));
    expect(mocks.serverFetch.mock.calls[1]).toEqual([`/raisons-absence-commande/${ID}`, { method: 'DELETE' }]);
  });
});

describe('erreurs de l’API', () => {
  it('API injoignable : message, pas de rafraîchissement', async () => {
    mocks.serverFetch.mockRejectedValue(new Error('réseau'));
    expect(await ajouterRaison(form({ libelle: 'R' }))).toBe("Impossible de joindre l'API.");
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it('statut en échec : message d’erreur, pas de rafraîchissement', async () => {
    mocks.serverFetch.mockResolvedValue(new Response('{}', { status: 500 }));
    expect(await supprimerQuestion(form({ id: ID }))).toMatch(/erreur/i);
    mocks.serverFetch.mockResolvedValue(new Response('{}', { status: 401 }));
    expect(await supprimerQuestion(form({ id: ID }))).toMatch(/Session expirée/);
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });
});
