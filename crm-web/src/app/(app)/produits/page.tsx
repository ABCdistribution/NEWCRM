import Link from 'next/link';
import {
  countArticles,
  listArticles,
  listMarques,
  listPem,
  listPromosActives,
  type ArticleRow,
  type Paginated,
} from '@/lib/api';
import { requireRole, TERRAIN, TOUS_ROLES } from '@/lib/roles';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge } from '@/components/badges';
import { ProduitsTable } from '@/components/produits-table';
import { ProduitsFiltreMarque } from '@/components/produits-filtre-marque';

export const metadata = { title: 'Les produits' };

const NB = new Intl.NumberFormat('fr-FR');
const fmt = (n: number | null) => (n == null ? '—' : NB.format(n));

const MSG_ERREUR = "Impossible de charger les produits. L'API est-elle démarrée ?";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

export default async function ProduitsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string; promo?: string; rappel?: string; marque?: string }>;
}) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;
  const terrain = TERRAIN.includes(me.role);

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  // Filtres : promos / PEM et rappel (bascules, combinables), marque (identifiant valide, sinon ignoré).
  const promo = sp.promo === '1';
  const rappel = sp.rappel === '1';
  const marque = typeof sp.marque === 'string' && UUID.test(sp.marque) ? sp.marque : undefined;

  const chargerArticles = async (): Promise<Paginated<ArticleRow> | null> => {
    try {
      return await listArticles({ search, page, promo, rappel, marqueId: marque });
    } catch {
      return null;
    }
  };
  // Liste et marques sont demandées en parallèle ; la liste des marques absente ne bloque pas la page.
  const [marques, result] = await Promise.all([listMarques(), chargerArticles()]);
  const error = result === null ? MSG_ERREUR : null;

  /** Adresse de la page avec un ou plusieurs filtres modifiés ; les autres sont conservés (la page repart de 1). */
  const lien = (modif: { promo?: boolean; rappel?: boolean }) => {
    const q = new URLSearchParams();
    if (search) q.set('search', search);
    if (modif.promo ?? promo) q.set('promo', '1');
    if (modif.rappel ?? rappel) q.set('rappel', '1');
    if (marque) q.set('marque', marque);
    const str = q.toString();
    return str ? `/produits?${str}` : '/produits';
  };
  const bascule = (actif: boolean) =>
    `inline-flex h-9 items-center rounded-full border px-3.5 text-xs font-semibold transition ${FOCUS} ${
      actif ? 'border-brand bg-brand text-white' : 'border-neutral-200 bg-white text-neutral-600 hover:bg-neutral-100'
    }`;
  const filtresActifs = promo || rappel || marque !== undefined;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Produits</h1>
        <SearchBar placeholder="Libellé, marque, code article, code-barres…" />
      </div>

      {terrain ? <KpisTerrain /> : <KpisEncadrement />}

      <div className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-3 shadow-card" role="group" aria-label="Filtres des produits">
        <Link href={lien({ promo: !promo })} aria-pressed={promo} className={bascule(promo)}>
          Promos / PEM
        </Link>
        <Link href={lien({ rappel: !rappel })} aria-pressed={rappel} className={bascule(rappel)}>
          En rappel
        </Link>
        {marques && marques.length > 0 ? <ProduitsFiltreMarque marques={marques} marque={marque} /> : null}
        {filtresActifs ? (
          <Link
            href={search ? `/produits?search=${encodeURIComponent(search)}` : '/produits'}
            className={`ml-auto text-xs font-medium text-neutral-500 underline-offset-2 hover:underline ${FOCUS}`}
          >
            Réinitialiser
          </Link>
        ) : null}
      </div>

      {error || !result ? (
        <p
          role="alert"
          className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300"
        >
          {error ?? MSG_ERREUR}
        </p>
      ) : (
        <>
          {terrain ? <CatalogueTerrain articles={result.data} /> : <ProduitsTable articles={result.data} />}
          <Pagination
            total={result.total}
            page={result.page}
            limit={result.limit}
            params={{
              search,
              ...(promo ? { promo: '1' } : {}),
              ...(rappel ? { rappel: '1' } : {}),
              ...(marque ? { marque } : {}),
            }}
          />
        </>
      )}
    </div>
  );
}

type Chiffre = { valeur: string; libelle: string; ton?: 'ok' | 'alerte'; titre?: string };

/**
 * Ligne de chiffres du catalogue, compacte (plus de grandes cartes) : le total en tête, puis les autres chiffres avec
 * un point de couleur (vert = bon, orange = à contrôler). Chaque chiffre est écrit en toutes lettres : la couleur
 * n'est jamais seule à porter le sens.
 */
function ResumeCatalogue({ principal, autres }: { principal: Chiffre; autres: Chiffre[] }) {
  return (
    <p className="flex flex-wrap items-baseline gap-x-4 gap-y-1" aria-live="polite">
      <span className="text-2xl font-bold tabular-nums">{principal.valeur}</span>
      <span className="text-neutral-500">{principal.libelle}</span>
      {autres.map((c) => (
        <span key={c.libelle} title={c.titre} className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-700">
          <span
            className={`h-2 w-2 rounded-full ${c.ton === 'ok' ? 'bg-positif' : c.ton === 'alerte' ? 'bg-attention' : 'bg-neutral-400'}`}
            aria-hidden
          />
          <span className="tabular-nums">{c.valeur}</span> {c.libelle}
        </span>
      ))}
    </p>
  );
}

/** Chiffres terrain : références, promos en cours, mises en avant actives, rappels. */
async function KpisTerrain() {
  const [total, rappels, promos, pem] = await Promise.all([
    countArticles({}),
    countArticles({ rappel: true }),
    listPromosActives(),
    listPem({ actifsSeulement: true }),
  ]);
  return (
    <ResumeCatalogue
      principal={{ valeur: fmt(total), libelle: 'références' }}
      autres={[
        { valeur: fmt(promos?.length ?? null), libelle: 'promos actives' },
        { valeur: fmt(pem?.length ?? null), libelle: 'mises en avant' },
        { valeur: fmt(rappels), libelle: 'en rappel', ton: rappels ? 'alerte' : undefined },
      ]}
    />
  );
}

/**
 * Chiffres de l'encadrement : uniquement des chiffres réels de l'API. Les évolutions « vs mois dernier » et les ventes
 * moyennes mensuelles ont été retirées : l'API ne fournit ni historique du catalogue ni ventes par produit.
 */
async function KpisEncadrement() {
  const [total, actifs, rappels] = await Promise.all([
    countArticles({}),
    countArticles({ actif: true }),
    countArticles({ rappel: true }),
  ]);
  return (
    <ResumeCatalogue
      principal={{ valeur: fmt(total), libelle: 'produits au catalogue' }}
      autres={[
        { valeur: fmt(actifs), libelle: 'actifs', ton: 'ok', titre: 'Actifs et commandables' },
        {
          valeur: fmt(rappels),
          libelle: rappels ? 'en rappel à contrôler' : 'en rappel',
          ton: rappels ? 'alerte' : undefined,
          titre: 'Produits à retour autorisé — à contrôler sur le terrain',
        },
      ]}
    />
  );
}

/** Catalogue côté terrain : cartes sous md, tableau au-dessus. */
function CatalogueTerrain({ articles }: { articles: ArticleRow[] }) {
  return (
    <>
      <ul className="flex flex-col gap-2.5 md:hidden">
        {articles.map((a) => (
          <li key={a.id} className="rounded-2xl bg-white p-4 shadow-card">
            <div className="flex items-start justify-between gap-2">
              <p className="min-w-0 text-sm font-medium">{a.libelle}</p>
              <ActiveBadge active={a.actif} />
            </div>
            <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-neutral-500">
              <span className="font-mono">{a.codeAs400}</span>
              {a.marque?.nom ? <span>{a.marque.nom}</span> : null}
              {a.gamme?.nom ? <span>{a.gamme.nom}</span> : null}
              {a.pcb ? <span>PCB {a.pcb}</span> : null}
            </div>
          </li>
        ))}
        {articles.length === 0 ? (
          <li className="rounded-2xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
            Aucun produit trouvé.
          </li>
        ) : null}
      </ul>

      <div className="hidden overflow-x-auto rounded-xl bg-white shadow-card md:block">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">Code</th>
              <th className="px-4 py-2.5 font-medium">Libellé</th>
              <th className="px-4 py-2.5 font-medium">Marque</th>
              <th className="px-4 py-2.5 font-medium">Gamme</th>
              <th className="px-4 py-2.5 font-medium">PCB</th>
              <th className="px-4 py-2.5 font-medium">Statut</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {articles.map((a) => (
              <tr key={a.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-2.5 font-mono text-xs">{a.codeAs400}</td>
                <td className="px-4 py-2.5">{a.libelle}</td>
                <td className="px-4 py-2.5">{a.marque?.nom ?? '—'}</td>
                <td className="px-4 py-2.5">{a.gamme?.nom ?? '—'}</td>
                <td className="px-4 py-2.5">{a.pcb ?? '—'}</td>
                <td className="px-4 py-2.5">
                  <ActiveBadge active={a.actif} />
                </td>
              </tr>
            ))}
            {articles.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">
                  Aucun produit trouvé.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </>
  );
}
