import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  articlesPresents,
  changementsApresDeplacement,
  cheminCentrale,
  enseignesVisibles,
  grouperParCentrale,
  lireChangements,
  ordreValide,
  ORDRE_MAX,
  pluriel,
  prochainOrdre,
  texteRecherche,
  type CentraleAdmin,
  type ProduitIndispensable,
} from './produits-indispensables';
import {
  ajouterProduitIndispensable,
  rechercherArticles,
  reordonnerProduitsIndispensables,
  retirerProduitIndispensable,
} from './produits-indispensables-actions';

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
const ID2 = '223e4567-e89b-42d3-a456-426614174000';
const ID3 = '323e4567-e89b-42d3-a456-426614174000';
const ok = () => new Response('{}', { status: 200 });

const form = (champs: Record<string, string>) => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(champs)) fd.set(k, v);
  return fd;
};

const ligne = (id: string, ordre: number, centraleId = ID, articleId = `art-${id}`): ProduitIndispensable => ({
  id,
  centraleId,
  articleId,
  ordre,
  article: { id: articleId, codeAs400: 'A1', libelle: 'Produit', gencode: null, marque: null },
});

const centrale = (id: string, nom: string, nbClients: number, parentId: string | null = null): CentraleAdmin => ({
  id,
  code: `C-${nom}`,
  nom,
  parentId,
  nbClients,
});

beforeEach(() => {
  mocks.serverFetch.mockReset().mockResolvedValue(ok());
  mocks.exigerRole.mockReset().mockResolvedValue({ role: 'ADMIN' });
  mocks.revalidatePath.mockReset();
  vi.spyOn(console, 'error').mockImplementation(() => {});
});

describe('validation', () => {
  it("position : entier de 0 à la borne de l'API", () => {
    expect(ordreValide('0')).toBe(0);
    expect(ordreValide(' 12 ')).toBe(12);
    expect(ordreValide(ORDRE_MAX)).toBe(ORDRE_MAX);
    for (const v of ['', ' ', '-1', '1.5', 'abc', String(ORDRE_MAX + 1), null, undefined, NaN]) {
      expect(ordreValide(v)).toBeNull();
    }
  });

  it('texte de recherche : compacté, borné, minimum 2 caractères', () => {
    expect(texteRecherche('  lait   fraise ')).toBe('lait fraise');
    expect(texteRecherche('a')).toBeNull();
    expect(texteRecherche('   ')).toBeNull();
    expect(texteRecherche(undefined)).toBeNull();
    expect(texteRecherche('x'.repeat(200))).toHaveLength(80);
  });

  it('liste de changements : JSON bien formé, ids UUID, positions valides', () => {
    expect(lireChangements(JSON.stringify([{ id: ID, ordre: 0 }, { id: ID2, ordre: 3 }]))).toEqual({
      changements: [
        { id: ID, ordre: 0 },
        { id: ID2, ordre: 3 },
      ],
      erreur: null,
    });
    const invalides = [
      'pas du json',
      '[]',
      '{}',
      'null',
      JSON.stringify([{ id: 'x', ordre: 0 }]),
      JSON.stringify([{ id: ID, ordre: -1 }]),
      JSON.stringify([{ id: ID, ordre: 1.5 }]),
      JSON.stringify([{ id: ID }]),
      JSON.stringify([null]),
      JSON.stringify(Array.from({ length: 501 }, () => ({ id: ID, ordre: 0 }))),
    ];
    for (const brut of invalides) expect(lireChangements(brut)).toEqual({ changements: null, erreur: 'Déplacement invalide.' });
  });
});

describe('logique de liste', () => {
  it('groupe par enseigne en gardant l’ordre reçu', () => {
    const g = grouperParCentrale([ligne('a', 0, ID), ligne('b', 0, ID2), ligne('c', 1, ID)]);
    expect(g.get(ID)?.map((l) => l.id)).toEqual(['a', 'c']);
    expect(g.get(ID2)?.map((l) => l.id)).toEqual(['b']);
    expect(g.get(ID3)).toBeUndefined();
  });

  it('prochaine position : à la suite, 0 si liste vide, bornée', () => {
    expect(prochainOrdre([])).toBe(0);
    expect(prochainOrdre([{ ordre: 0 }, { ordre: 4 }, { ordre: 2 }])).toBe(5);
    expect(prochainOrdre([{ ordre: ORDRE_MAX }])).toBe(ORDRE_MAX);
  });

  it('articles déjà présents', () => {
    const presents = articlesPresents([ligne('a', 0, ID, 'x'), ligne('b', 1, ID, 'y')]);
    expect(presents.has('x')).toBe(true);
    expect(presents.has('z')).toBe(false);
  });

  it('déplacement : échange et ne renvoie que les positions modifiées', () => {
    const liste = [ligne('a', 0), ligne('b', 1), ligne('c', 2)];
    expect(changementsApresDeplacement(liste, 1, 'haut')).toEqual([
      { id: 'b', ordre: 0 },
      { id: 'a', ordre: 1 },
    ]);
    expect(changementsApresDeplacement(liste, 1, 'bas')).toEqual([
      { id: 'c', ordre: 1 },
      { id: 'b', ordre: 2 },
    ]);
  });

  it('déplacement : renumérote les ex aequo (positions à 0 par défaut)', () => {
    const liste = [ligne('a', 0), ligne('b', 0), ligne('c', 0)];
    // Après échange : b, a, c → b:0 (déjà 0, inchangé), a:1, c:2.
    expect(changementsApresDeplacement(liste, 1, 'haut')).toEqual([
      { id: 'a', ordre: 1 },
      { id: 'c', ordre: 2 },
    ]);
  });

  it('déplacement impossible aux bords ou hors liste', () => {
    const liste = [ligne('a', 0), ligne('b', 1)];
    expect(changementsApresDeplacement(liste, 0, 'haut')).toEqual([]);
    expect(changementsApresDeplacement(liste, 1, 'bas')).toEqual([]);
    expect(changementsApresDeplacement(liste, -1, 'bas')).toEqual([]);
    expect(changementsApresDeplacement(liste, 5, 'haut')).toEqual([]);
    expect(changementsApresDeplacement([], 0, 'bas')).toEqual([]);
  });
});

describe('enseignes', () => {
  const centrales = [
    centrale(ID, 'Leclerc', 12),
    centrale(ID2, 'Carrefour Hyper', 0),
    centrale(ID3, 'Système U', 0),
    centrale('4', 'Élan', 3),
  ];
  const comptes = new Map([[ID3, 2]]);

  it('par défaut : enseignes avec magasins ou avec une liste, le reste est compté', () => {
    const { visibles, masquees } = enseignesVisibles(centrales, comptes, '', false);
    expect(visibles.map((c) => c.id)).toEqual([ID, ID3, '4']);
    expect(masquees).toBe(1);
  });

  it('toutes les enseignes sur demande', () => {
    const { visibles, masquees } = enseignesVisibles(centrales, comptes, '', true);
    expect(visibles).toHaveLength(4);
    expect(masquees).toBe(0);
  });

  it('filtre par nom ou code, sans accent ni casse', () => {
    expect(enseignesVisibles(centrales, comptes, 'elan', true).visibles.map((c) => c.id)).toEqual(['4']);
    expect(enseignesVisibles(centrales, comptes, 'SYSTEME', true).visibles.map((c) => c.id)).toEqual([ID3]);
    expect(enseignesVisibles(centrales, comptes, 'c-lecl', true).visibles.map((c) => c.id)).toEqual([ID]);
    expect(enseignesVisibles(centrales, comptes, 'zzz', true).visibles).toEqual([]);
  });

  it('chemin de la centrale : ancêtres puis nom, sans boucler sur un cycle', () => {
    const racine = centrale('r', 'Groupe', 0);
    const fille = centrale('f', 'Enseigne', 0, 'r');
    const feuille = centrale('l', 'Magasin', 5, 'f');
    const parId = new Map([racine, fille, feuille].map((c) => [c.id, c]));
    expect(cheminCentrale(feuille, parId)).toBe('Groupe › Enseigne › Magasin');
    expect(cheminCentrale(racine, parId)).toBe('Groupe');

    const a = centrale('a', 'A', 0, 'b');
    const b = centrale('b', 'B', 0, 'a');
    expect(cheminCentrale(a, new Map([a, b].map((c) => [c.id, c])))).toBe('B › A');
  });

  it('pluriel', () => {
    expect(pluriel(0, 'magasin')).toBe('0 magasin');
    expect(pluriel(1, 'magasin')).toBe('1 magasin');
    expect(pluriel(2, 'magasin')).toBe('2 magasins');
    expect(pluriel(3, 'produit indispensable', 'produits indispensables')).toBe('3 produits indispensables');
  });
});

describe('Server Actions', () => {
  it('refusent un non-administrateur sans appeler l’API', async () => {
    mocks.exigerRole.mockRejectedValue(new Error('refus'));
    const reponses = [
      await ajouterProduitIndispensable(form({ centraleId: ID, articleId: ID2 })),
      await retirerProduitIndispensable(form({ id: ID })),
      await reordonnerProduitsIndispensables(form({ changements: JSON.stringify([{ id: ID, ordre: 0 }]) })),
    ];
    for (const r of reponses) expect(typeof r).toBe('string');
    expect((await rechercherArticles('lait')).erreur).toEqual(expect.any(String));
    expect(mocks.serverFetch).not.toHaveBeenCalled();
    expect(mocks.exigerRole).toHaveBeenCalledWith(['ADMIN']);
  });

  it('ajout : POST avec enseigne, article et position', async () => {
    expect(await ajouterProduitIndispensable(form({ centraleId: ID, articleId: ID2, ordre: '3' }))).toBeNull();
    const [chemin, init] = mocks.serverFetch.mock.calls[0];
    expect(chemin).toBe('/produits-indispensables');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body)).toEqual({ centraleId: ID, articleId: ID2, ordre: 3 });
    expect(mocks.revalidatePath).toHaveBeenCalledWith('/admin');
  });

  it('ajout : ids et position invalides refusés avant l’appel', async () => {
    expect(await ajouterProduitIndispensable(form({ centraleId: '../x', articleId: ID2 }))).toBe('Enseigne invalide.');
    expect(await ajouterProduitIndispensable(form({ centraleId: ID, articleId: 'abc' }))).toBe('Article invalide.');
    expect(await ajouterProduitIndispensable(form({ centraleId: ID, articleId: ID2, ordre: '-2' }))).toBe('Position invalide.');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('retrait : DELETE sur l’id encodé, id invalide refusé', async () => {
    expect(await retirerProduitIndispensable(form({ id: ID }))).toBeNull();
    expect(mocks.serverFetch.mock.calls[0][0]).toBe(`/produits-indispensables/${ID}`);
    expect(mocks.serverFetch.mock.calls[0][1].method).toBe('DELETE');
    expect(await retirerProduitIndispensable(form({ id: '1/../2' }))).toBe('Produit invalide.');
    expect(mocks.serverFetch).toHaveBeenCalledTimes(1);
  });

  it('erreur de l’API : message affiché et rien de revalidé', async () => {
    mocks.serverFetch.mockImplementation(async () => new Response(JSON.stringify({ message: 'Article introuvable' }), { status: 404 }));
    expect(await ajouterProduitIndispensable(form({ centraleId: ID, articleId: ID2 }))).toContain('Article introuvable');
    expect(await retirerProduitIndispensable(form({ id: ID }))).toContain('Article introuvable');
    expect(mocks.revalidatePath).not.toHaveBeenCalled();
  });

  it('API injoignable : message français', async () => {
    mocks.serverFetch.mockRejectedValue(new Error('ECONNREFUSED'));
    expect(await retirerProduitIndispensable(form({ id: ID }))).toBe("Impossible de joindre l'API.");
  });

  it('déplacement : un PATCH par ligne, arrêt à la première erreur, revalidation dans tous les cas', async () => {
    const changements = JSON.stringify([
      { id: ID, ordre: 1 },
      { id: ID2, ordre: 0 },
    ]);
    expect(await reordonnerProduitsIndispensables(form({ changements }))).toBeNull();
    expect(mocks.serverFetch).toHaveBeenCalledTimes(2);
    expect(mocks.serverFetch.mock.calls[0][0]).toBe(`/produits-indispensables/${ID}`);
    expect(mocks.serverFetch.mock.calls[0][1].method).toBe('PATCH');
    expect(JSON.parse(mocks.serverFetch.mock.calls[1][1].body)).toEqual({ ordre: 0 });

    mocks.serverFetch.mockReset().mockResolvedValue(new Response('{}', { status: 404 }));
    mocks.revalidatePath.mockReset();
    expect(typeof (await reordonnerProduitsIndispensables(form({ changements })))).toBe('string');
    expect(mocks.serverFetch).toHaveBeenCalledTimes(1);
    expect(mocks.revalidatePath).toHaveBeenCalledWith('/admin');
  });

  it('déplacement : changements invalides refusés', async () => {
    expect(await reordonnerProduitsIndispensables(form({ changements: '[{"id":"x","ordre":1}]' }))).toBe('Déplacement invalide.');
    expect(mocks.serverFetch).not.toHaveBeenCalled();
  });

  it('recherche : texte court sans appel, sinon GET /articles borné à 10 résultats', async () => {
    expect(await rechercherArticles('a')).toEqual({ data: [] });
    expect(mocks.serverFetch).not.toHaveBeenCalled();

    mocks.serverFetch.mockResolvedValue(
      new Response(
        JSON.stringify({
          data: [{ id: ID, codeAs400: 'X1', libelle: 'Vernis', gencode: '123', actif: true, marque: { nom: 'ABC' }, stock: 4, pcb: 6 }],
          total: 1,
          page: 1,
          limit: 10,
        }),
        { status: 200 },
      ),
    );
    const reponse = await rechercherArticles(' vernis rouge ');
    expect(mocks.serverFetch.mock.calls[0][0]).toBe('/articles?search=vernis+rouge&limit=10');
    expect(reponse).toEqual({
      data: [{ id: ID, codeAs400: 'X1', libelle: 'Vernis', gencode: '123', actif: true, marque: { nom: 'ABC' } }],
    });
  });

  it('recherche : erreur de l’API et réponse illisible', async () => {
    mocks.serverFetch.mockResolvedValue(new Response('{}', { status: 500 }));
    expect((await rechercherArticles('vernis')).erreur).toContain('500');
    mocks.serverFetch.mockResolvedValue(new Response('{"data":"non"}', { status: 200 }));
    expect((await rechercherArticles('vernis')).erreur).toBe('La recherche a renvoyé une réponse illisible.');
  });
});
