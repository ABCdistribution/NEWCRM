import type { ReactElement } from 'react';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CatalogueTerrain } from '@/components/catalogue-terrain';
import { ProduitsTable } from '@/components/produits-table';
import { FICHIERS_ROUTES, PAGES } from '@/test/pages-reelles';
import { lireFichierApp, lireGarde } from '@/test/gardes-pages';
import { FIL, ID_REMPLACANT, RICHE } from '@/test/produit-exemple';
import { ApiIndisponibleError, getArticle, type ArticleDetail, type ArticleRow, type Role } from './api';
import { ENCADREMENT, ROLES_COMMANDES_VISITES, TERRAIN, TOUS_ROLES, ErreurServiceIndisponible } from './roles';
import { ROUTES } from './routes';

// Aucun réseau, aucune session : le cookie (`./session`), la navigation et les en-têtes de Next sont remplacés, et
// `fetch` est un faux qui répond selon le chemin demandé à l'API (/auth/me, /articles/:id).
// `redirect` / `notFound` se comportent comme dans Next : ils ne rendent jamais la main (ils lèvent).
const mocks = vi.hoisted(() => ({
  getToken: vi.fn(),
  redirect: vi.fn(),
  notFound: vi.fn(),
  headers: vi.fn(),
  fetch: vi.fn(),
}));
vi.mock('./session', () => ({ getToken: mocks.getToken, apiBase: () => 'http://api.test' }));
vi.mock('next/navigation', () => ({
  redirect: mocks.redirect,
  notFound: mocks.notFound,
  unstable_rethrow: (e: unknown) => {
    throw e;
  },
}));
vi.mock('next/headers', () => ({ headers: mocks.headers }));

const { default: ProduitFiche } = await import('@/app/(app)/produits/[id]/page');

const ID = FIL.id;

const json = (corps: unknown, status = 200) =>
  new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

const utilisateur = (role: string) => ({
  id: '00000000-0000-4000-8000-000000000001',
  username: `test.${role.toLowerCase()}`,
  displayName: `[TEST] ${role}`,
  email: null,
  role,
  idRepr: null,
  poste: null,
});

/** Ce que répond l'API : l'utilisateur (ou un statut d'erreur de /auth/me) et la fiche (ou un statut d'erreur). */
function api({ role = 'COMMERCIAL', article = FIL }: { role?: string | number; article?: unknown | number } = {}) {
  mocks.fetch.mockImplementation(async (url: string) => {
    const chemin = String(url).replace('http://api.test', '');
    if (chemin === '/auth/me') return typeof role === 'number' ? json({ message: 'KO' }, role) : json(utilisateur(role));
    if (chemin.startsWith('/articles/')) return typeof article === 'number' ? json({ message: 'KO' }, article) : json(article);
    return json({ message: 'inconnu' }, 404);
  });
}

/** Chemins demandés à l'API depuis le début du test. */
const appels = (): string[] => mocks.fetch.mock.calls.map(([url]) => String(url).replace('http://api.test', ''));

/** Rend la page comme Next : composant serveur asynchrone, puis balisage HTML. */
async function rendre(id: string = ID): Promise<string> {
  const element = (await ProduitFiche({ params: Promise.resolve({ id }) })) as ReactElement;
  return renderToStaticMarkup(element);
}

/** Les espaces insécables des formats français deviennent des espaces simples. */
const normal = (html: string): string => html.replace(/[  ]/g, ' ');

beforeEach(() => {
  mocks.getToken.mockReset().mockResolvedValue('jwt-de-test');
  mocks.headers.mockReset().mockResolvedValue(new Headers());
  mocks.fetch.mockReset();
  mocks.redirect.mockReset().mockImplementation((url: string) => {
    throw new Error(`NEXT_REDIRECT:${url}`);
  });
  mocks.notFound.mockReset().mockImplementation(() => {
    throw new Error('NEXT_NOT_FOUND');
  });
  vi.stubGlobal('fetch', mocks.fetch);
  api();
});

describe('route /produits/[id]', () => {
  it('la page existe, dans le groupe (app), sans entrée de menu propre (elle dépend de /produits)', () => {
    const page = PAGES.find((p) => p.url === '/produits/[id]');
    expect(page?.fichier).toBe('(app)/produits/[id]/page.tsx');
    expect(page?.groupes).toEqual(['app']);
    expect(ROUTES.some((r) => r.href === '/produits/[id]')).toBe(false);
    expect(ROUTES.find((r) => r.href === '/produits')?.roles).toEqual(TOUS_ROLES);
  });

  it('la garde de la page = TOUS_ROLES, comme /produits', () => {
    const garde = lireGarde(lireFichierApp('(app)/produits/[id]/page.tsx'), { TOUS_ROLES, ENCADREMENT, TERRAIN, ROLES_COMMANDES_VISITES });
    expect(garde).toEqual({ roles: [...TOUS_ROLES].sort() });
  });

  it("la page ne s'ajoute pas aux route handlers (aucune route /api côté navigateur)", () => {
    expect(FICHIERS_ROUTES.filter((f) => f.type === 'route' && f.url.startsWith('/produits'))).toEqual([]);
  });
});

describe('garde de la page', () => {
  it.each(TOUS_ROLES)('rôle %s : la fiche s’affiche', async (role) => {
    api({ role });
    const html = await rendre();
    expect(html).toContain('AC-FIL POLY 200M ROSE');
    expect(html).not.toContain('Accès refusé');
  });

  it('rôle inconnu : écran « Accès refusé », la fiche n’est jamais demandée à l’API', async () => {
    api({ role: 'STAGIAIRE' as Role });
    const html = await rendre();
    expect(html).toContain('Accès refusé');
    expect(html).not.toContain('AC-FIL POLY 200M ROSE');
    expect(appels()).toEqual(['/auth/me']);
  });

  it('pas de session : redirection vers /login, la fiche n’est jamais demandée', async () => {
    api({ role: 401 });
    await expect(rendre()).rejects.toThrow('NEXT_REDIRECT:/login');
    expect(appels()).toEqual(['/auth/me']);
  });

  it('API indisponible : erreur de service (pas de redirection vers /login, pas de faux refus)', async () => {
    api({ role: 503 });
    await expect(rendre()).rejects.toBeInstanceOf(ErreurServiceIndisponible);
    expect(mocks.redirect).not.toHaveBeenCalled();
  });
});

describe('chargement de la fiche', () => {
  it('appelle GET /articles/<id> avec l’identifiant validé', async () => {
    await rendre();
    expect(appels()).toEqual(['/auth/me', `/articles/${ID}`]);
  });

  it.each(['abc', '../admin', `${ID}/../users`, `${ID}?x=1`, '..%2Fadmin', ''])(
    'identifiant « %s » : 404, jamais inséré dans un chemin d’API',
    async (id) => {
      await expect(rendre(id)).rejects.toThrow('NEXT_NOT_FOUND');
      expect(appels()).toEqual(['/auth/me']);
    },
  );

  it.each([404, 403])('HTTP %s sur la fiche : page introuvable', async (statut) => {
    api({ article: statut });
    await expect(rendre()).rejects.toThrow('NEXT_NOT_FOUND');
  });

  it('401 sur la fiche : redirection vers /login (pas un faux 404)', async () => {
    api({ article: 401 });
    await expect(rendre()).rejects.toThrow('NEXT_REDIRECT:/login');
  });

  it.each([500, 503])('HTTP %s sur la fiche : service indisponible (pas un faux 404)', async (statut) => {
    api({ article: statut });
    await expect(rendre()).rejects.toBeInstanceOf(ApiIndisponibleError);
    expect(mocks.notFound).not.toHaveBeenCalled();
  });

  it('réponse d’une API plus ancienne (sans les listes du détail) : service indisponible, jamais « Aucun tarif »', async () => {
    const { tarifs: _t, promos: _p, remplacements: _r, ...ancien } = FIL;
    api({ article: ancien });
    await expect(getArticle(ID)).rejects.toBeInstanceOf(ApiIndisponibleError);
    await expect(rendre()).rejects.toBeInstanceOf(ApiIndisponibleError);
    expect(mocks.notFound).not.toHaveBeenCalled();
  });

  it.each(['tarifs', 'promos', 'remplacements'] as const)('réponse sans « %s » : service indisponible', async (cle) => {
    const { [cle]: _absent, ...partiel } = FIL;
    api({ article: partiel });
    await expect(getArticle(ID)).rejects.toBeInstanceOf(ApiIndisponibleError);
  });

  it('réponse complète : les listes du détail sont conservées telles quelles', async () => {
    api({ article: RICHE });
    const article = (await getArticle(RICHE.id)) as ArticleDetail;
    expect(article.tarifs).toEqual(RICHE.tarifs);
    expect(article.promos).toEqual(RICHE.promos);
    expect(article.remplacements).toEqual(RICHE.remplacements);
  });
});

describe('contenu de la fiche', () => {
  it('en-tête : titre, retour vers /produits, pastille Actif, code et marque', async () => {
    const html = await rendre();
    expect(html).toMatch(/<h1[^>]*>AC-FIL POLY 200M ROSE<\/h1>/);
    expect(html).toContain('href="/produits"');
    expect(html).toContain('aria-label="Retour aux produits"');
    expect(html).toContain('Actif');
    expect(html).not.toContain('Inactif');
  });

  it('« Informations générales » : tous les libellés, dans l’ordre, avec les valeurs de la demande', async () => {
    const html = await rendre();
    expect(html).toContain('Informations générales');
    const libelles = [
      'Libellé', 'ID-AS400', 'Famille', 'Gencode', 'Type article', 'TVA', 'Famille Plan', 'Gamme', 'Marque',
      'Famille ACD', 'Sous famille ACD', 'Statut', 'Sous statut', 'Retour autorisé', 'PCB',
    ];
    const positions = libelles.map((l) => html.indexOf(`<dt class="text-xs text-neutral-400">${l}</dt>`));
    expect(positions.every((p) => p >= 0)).toBe(true);
    expect([...positions].sort((a, b) => a - b)).toEqual(positions);

    const valeur = (label: string): string | undefined =>
      new RegExp(`<dt[^>]*>${label}</dt><dd[^>]*>([^<]*)</dd>`).exec(html)?.[1];
    expect(valeur('Libellé')).toBe('AC-FIL POLY 200M ROSE');
    expect(valeur('ID-AS400')).toBe('20738');
    expect(valeur('Famille')).toBe('TEXTILE');
    expect(valeur('Gencode')).toBe('3666085207382');
    expect(valeur('Type article')).toBe('Textile');
    expect(valeur('TVA')).toBe('Taux normal');
    expect(valeur('Famille Plan')).toBe('ATELIER C&amp;C');
    expect(valeur('Gamme')).toBe('MERCERIE');
    expect(valeur('Marque')).toBe('ATELIER C&amp;C');
    expect(valeur('Famille ACD')).toBe('FIL MERCERIE');
    expect(valeur('Sous famille ACD')).toBe('non définie');
    expect(valeur('Statut')).toBe('TEXT');
    expect(valeur('Sous statut')).toBe('ACTIF');
    expect(valeur('Retour autorisé')).toBe('Non');
  });

  it('ID-AS400 et gencode en police à chasse fixe', async () => {
    const html = await rendre();
    expect(html).toMatch(/<dt[^>]*>ID-AS400<\/dt><dd class="[^"]*font-mono[^"]*">20738<\/dd>/);
    expect(html).toMatch(/<dt[^>]*>Gencode<\/dt><dd class="[^"]*font-mono[^"]*">3666085207382<\/dd>/);
  });

  it('« Code-barres » : EAN-13 dessiné pour le gencode de la demande', async () => {
    const html = await rendre();
    expect(html).toContain('>Code-barres<');
    expect(html).toContain('role="img"');
    expect(html).toContain('aria-label="Code-barres EAN-13 3666085207382"');
  });

  it.each([
    ['clé de contrôle fausse', '3666085207383'],
    ['longueur invalide', '36660852'],
    ['12 chiffres (base de démo)', '376123450031'],
  ])('gencode non conforme EAN (%s) : un code-barres Code 128 est dessiné pour le numéro exact', async (_libelle, gencode) => {
    api({ article: { ...FIL, gencode } });
    const html = await rendre();
    expect(html).toContain('role="img"'); // les icônes de carte sont décoratives (aria-hidden) : seul le code-barres porte role="img"
    expect(html).toContain(`aria-label="Code-barres Code 128 ${gencode}"`);
    expect(html).not.toContain('Code-barres EAN-13'); // jamais présenté comme un EAN
    expect(html).toContain(gencode);
  });

  it('gencode non encodable (caractères hors ASCII) : le numéro seul, aucun dessin', async () => {
    api({ article: { ...FIL, gencode: 'réf-é' } });
    const html = await rendre();
    expect(html).not.toContain('role="img"');
    expect(html).toContain('réf-é');
  });

  it('gencode absent : « — » et aucun dessin', async () => {
    api({ article: { ...FIL, gencode: null } });
    const html = await rendre();
    expect(html).not.toContain('role="img"');
    expect(html).toMatch(/<dt[^>]*>Gencode<\/dt><dd[^>]*>—<\/dd>/);
  });

  it('« Tarifs » : un seul tarif = une ligne, montant en euros à deux décimales', async () => {
    const html = normal(await rendre());
    expect(html).toContain('>Tarifs<');
    expect(html).toContain('<th scope="col" class="px-5 py-2 font-medium">Code tarif</th>');
    expect(html).toContain('<td class="px-5 py-2.5 font-mono text-xs">80</td>');
    expect(html).toContain('3,50 €');
    expect([...html.matchAll(/<tr>/g)]).toHaveLength(1); // le corps du tableau (l'en-tête porte une classe)
  });

  it('« Tarifs » : un tarif à quatre décimales n’est pas arrondi', async () => {
    api({ article: { ...FIL, tarifs: [{ codeTarif: '80', montant: 0.1235 }], prixIndicatif: 0.1235 } });
    const html = normal(await rendre());
    expect(html).toContain('0,1235 €');
    expect(html).not.toContain('0,12 €');
  });

  it('« Tarifs » : plusieurs tarifs dans l’ordre reçu', async () => {
    api({ article: RICHE });
    const html = normal(await rendre(RICHE.id));
    expect(html.indexOf('4,90 €')).toBeGreaterThan(0);
    expect(html.indexOf('1 234,50 €')).toBeGreaterThan(html.indexOf('4,90 €'));
  });

  it('« Tarifs » : aucun tarif = « — »', async () => {
    api({ article: { ...FIL, tarifs: [], prixIndicatif: null } });
    const html = await rendre();
    expect(html).toContain('<span aria-hidden="true">—</span>');
    expect(html).toContain('Aucun tarif');
    expect(html).not.toContain('Code tarif');
  });

  it('« Stock et remplacement » : stock disponible et état (OK au-dessus du PCB)', async () => {
    const html = await rendre();
    expect(html).toContain('Stock et remplacement');
    expect(html).toContain('Stock disponible');
    expect(html).toMatch(/text-3xl font-bold tabular-nums text-emerald-700">48<\/span>/);
    expect(html).toContain('>OK<');
  });

  it('stock faible (sous le PCB) et rupture', async () => {
    api({ article: { ...FIL, stock: 5, pcb: 12 } });
    expect(await rendre()).toContain('>Faible<');
    api({ article: { ...FIL, stock: 0 } });
    const html = await rendre();
    expect(html).toContain('>Rupture<');
    expect(html).toMatch(/text-3xl font-bold tabular-nums text-red-600">0<\/span>/);
  });

  it('sans règle de remplacement : « Aucun produit de remplacement », pas de carte', async () => {
    const html = await rendre();
    expect(html).toContain('Aucun produit de remplacement');
    expect(html).not.toContain('>Produit de remplacement<');
  });

  it('une règle de remplacement : carte avec lien, code, marque, stock disponible et seuil de la règle', async () => {
    api({ article: RICHE });
    const html = await rendre(RICHE.id);
    expect(html).toContain('>Produit de remplacement<');
    expect(html).not.toContain('Aucun produit de remplacement');
    expect(html).toContain(`href="/produits/${ID_REMPLACANT}"`);
    expect(html).toMatch(/>GEL DOUCHE ECO 500ML<\/a>/);
    expect(html).toMatch(/<dt[^>]*>Code<\/dt><dd[^>]*>900015<\/dd>/);
    expect(html).toMatch(/<dt[^>]*>Marque<\/dt><dd[^>]*>ABC Cosmétique<\/dd>/);
    expect(html).toMatch(/font-semibold tabular-nums text-emerald-700">323<\/span>/);
    expect(html).toMatch(/<dt[^>]*>Seuil de la règle<\/dt><dd[^>]*>10<\/dd>/);
    expect(html).not.toContain('Aucun produit de remplacement');
  });

  it('le seuil est affiché au niveau de la règle, avant le produit remplaçant, jamais avec le stock du remplaçant', async () => {
    api({ article: RICHE });
    const html = await rendre(RICHE.id);
    const seuil = html.indexOf('Seuil de la règle');
    expect(seuil).toBeGreaterThan(html.indexOf('>Produit de remplacement<'));
    expect(seuil).toBeLessThan(html.indexOf('GEL DOUCHE ECO 500ML'));
    expect(html).not.toMatch(/<dt[^>]*>Seuil<\/dt>/);
  });

  it('plusieurs règles : une carte par règle ; remplaçant en rupture, sans seuil ni marque, inactif', async () => {
    const [premiere] = RICHE.remplacements;
    api({
      article: {
        ...RICHE,
        remplacements: [
          premiere,
          { seuil: null, article: { ...premiere.article, id: FIL.id, libelle: 'AUTRE', stock: 0, actif: false, marque: null } },
        ],
      },
    });
    const html = await rendre(RICHE.id);
    expect([...html.matchAll(/>Produit de remplacement</g)]).toHaveLength(2);
    expect(html).toContain('>Rupture<');
    expect(html).toContain('Inactif');
    expect(html).toMatch(/<dt[^>]*>Seuil de la règle<\/dt><dd[^>]*>—<\/dd>/);
    expect(html).toMatch(/<dt[^>]*>Marque<\/dt><dd[^>]*>—<\/dd>/);
  });

  it('identifiant du remplaçant encodé dans le lien', async () => {
    const [regle] = RICHE.remplacements;
    api({ article: { ...RICHE, remplacements: [{ ...regle, article: { ...regle.article, id: 'a/b?c' } }] } });
    expect(await rendre(RICHE.id)).toContain('href="/produits/a%2Fb%3Fc"');
  });

  it('fiche sans pastille d’en-tête : ni Promo, ni Mis en avant, ni Retour autorisé', async () => {
    const html = await rendre();
    expect(html).not.toContain('>Promo<');
    expect(html).not.toContain('>Mis en avant<');
    expect(html).not.toContain('text-amber-800">Retour autorisé<');
    expect(html).not.toContain('Promotions en cours');
    expect(html).not.toContain('>Détails<');
    expect(html).not.toContain('>Avantages<');
  });

  it('fiche complète : pastilles, promotions en cours, détails et avantages', async () => {
    api({ article: RICHE });
    const html = normal(await rendre(RICHE.id));
    expect(html).toContain('>Promo<');
    expect(html).toContain('>Mis en avant<');
    expect(html).toContain('bg-badge text-navy">Mis en avant<'); // contraste AA dans les deux espaces
    expect(html).toContain('text-amber-800">Retour autorisé<');
    expect(html).toContain('Promotions en cours');
    expect(html).toContain('Opération de novembre');
    expect(html).toMatch(/1 nov\.? 2026 au 30 nov\.? 2026/);
    expect(html).toContain('>Détails<');
    expect(html).toContain('Première ligne\nSeconde ligne');
    expect(html).toContain('whitespace-pre-line');
    expect(html).toContain('>Avantages<');
    expect(html).toContain('Sans parfum');
    expect(html).toMatch(/<dt[^>]*>Retour autorisé<\/dt><dd[^>]*>Oui<\/dd>/);
    expect(html).toContain('>Faible<'); // stock 6 < PCB 12
  });

  it('produit inactif : pastille Inactif', async () => {
    api({ article: { ...FIL, actif: false } });
    expect(await rendre()).toContain('Inactif');
  });

  it('le texte venant de l’API est échappé (jamais interprété comme du HTML)', async () => {
    api({ article: { ...RICHE, details: '<img src=x onerror=alert(1)>' } });
    const html = await rendre(RICHE.id);
    expect(html).toContain('GEL DOUCHE &lt;EXTRA&gt; 250ML');
    expect(html).not.toContain('<EXTRA>');
    expect(html).not.toContain('<img src=x');
    expect(html).toContain('&lt;img src=x onerror=alert(1)&gt;');
  });

  it('aucune couleur en dur ni dégradé : jetons du thème et couleurs sémantiques de statut seulement', async () => {
    api({ article: RICHE });
    const html = await rendre(RICHE.id);
    expect(html).not.toMatch(/#[0-9a-f]{3,8}\b/i);
    expect(html).not.toMatch(/gradient/i);
    expect(html).not.toMatch(/bg-\[|text-\[#|style=/);
  });

  it('responsive (utilisable dès 360 px) : une colonne par défaut, libellés qui passent à la ligne', async () => {
    const html = await rendre();
    expect(html).toContain('grid grid-cols-1');
    expect(html).toContain('sm:grid-cols-2');
    expect(html).toContain('xl:grid-cols-3');
    expect(html).toContain('break-words');
    expect(html).toContain('min-w-0');
  });

  it('focus visible sur les liens', async () => {
    api({ article: RICHE });
    const html = await rendre(RICHE.id);
    expect(html).toContain('focus-visible:outline-2');
    expect(html).toContain('focus-visible:outline-brand');
  });
});

describe('liste des produits : plus de modale, chaque produit est un lien vers sa fiche', () => {
  const ligne = (id: string, libelle: string, plus: Partial<ArticleRow> = {}): ArticleRow => ({
    id,
    codeAs400: '900030',
    libelle,
    gencode: null,
    typeArticle: null,
    statut: null,
    pcb: 12,
    stock: 6,
    actif: true,
    marque: { nom: 'ABC Cosmétique' },
    gamme: { nom: 'Soin' },
    famille: null,
    ...plus,
  });
  const articles = [ligne(ID, 'AC-FIL POLY 200M ROSE'), ligne(ID_REMPLACANT, 'GEL DOUCHE ECO 500ML', { actif: false })];

  it('vue encadrement : le libellé est un lien, toute la ligne est cliquable, colonnes inchangées', () => {
    const html = renderToStaticMarkup(createElement(ProduitsTable, { articles }));
    for (const id of [ID, ID_REMPLACANT]) expect(html).toContain(`href="/produits/${id}"`);
    expect([...html.matchAll(/<a /g)]).toHaveLength(2);
    expect(html).toContain('after:absolute after:inset-0'); // surface cliquable étendue à toute la ligne
    expect(html).toContain('<tr class="relative');
    for (const colonne of ['Code', 'Libellé', 'Marque', 'Gamme', 'Stock', 'Statut']) expect(html).toContain(`>${colonne}</th>`);
    expect(html).toMatch(/<a [^>]*>AC-FIL POLY 200M ROSE<\/a>/); // nom accessible = libellé
  });

  it('plus de modale ni de bouton imbriqué', () => {
    const html = renderToStaticMarkup(createElement(ProduitsTable, { articles }));
    expect(html).not.toContain('role="dialog"');
    expect(html).not.toContain('aria-modal');
    expect(html).not.toContain('<button');
    expect(html).not.toContain('tabindex');
    expect(html).not.toContain('Fermer');
  });

  it('anneau de focus sur toute la ligne au clavier', () => {
    const html = renderToStaticMarkup(createElement(ProduitsTable, { articles }));
    expect(html).toContain('focus-visible:after:outline-2');
    expect(html).toContain('focus-visible:after:outline-brand');
  });

  it('stock en rupture : même rouge que sur la fiche (red-600, contraste AA)', () => {
    const html = renderToStaticMarkup(createElement(ProduitsTable, { articles: [ligne(ID, 'EN RUPTURE', { stock: 0 })] }));
    expect(html).toContain('font-semibold text-red-600">0</td>');
    expect(html).not.toContain('text-red-500');
  });

  it('aucun produit : message, pas de lien', () => {
    const html = renderToStaticMarkup(createElement(ProduitsTable, { articles: [] }));
    expect(html).toContain('Aucun produit trouvé.');
    expect(html).not.toContain('<a ');
  });

  it('vue terrain : cartes et tableau portent chacun un lien vers la fiche', () => {
    const html = renderToStaticMarkup(createElement(CatalogueTerrain, { articles }));
    for (const id of [ID, ID_REMPLACANT]) {
      // une fois dans la carte (mobile), une fois dans le tableau (md et plus)
      expect([...html.matchAll(new RegExp(`href="/produits/${id}"`, 'g'))]).toHaveLength(2);
    }
    expect(html).toContain('after:rounded-2xl'); // la carte entière est cliquable, coins arrondis conservés
    for (const colonne of ['Code', 'Libellé', 'Marque', 'Gamme', 'PCB', 'Statut']) expect(html).toContain(`>${colonne}</th>`);
    expect(html).not.toContain('role="dialog"');
    expect(html).not.toContain('<button');
  });

  it('vue terrain sans produit : message, pas de lien', () => {
    const html = renderToStaticMarkup(createElement(CatalogueTerrain, { articles: [] }));
    expect(html).toContain('Aucun produit trouvé.');
    expect(html).not.toContain('<a ');
  });
});
