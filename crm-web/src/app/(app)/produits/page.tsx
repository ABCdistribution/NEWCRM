import { BadgePercent, Boxes, PackageX, Star } from 'lucide-react';
import {
  countArticles,
  listArticles,
  listPem,
  listPromosActives,
  type ArticleRow,
  type Paginated,
} from '@/lib/api';
import { requireRole, TERRAIN, TOUS_ROLES } from '@/lib/roles';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge } from '@/components/badges';
import { StatTile } from '@/components/stat-tile';
import { KpiTile } from '@/components/kpi-tile';
import { ProduitsTable } from '@/components/produits-table';

export const metadata = { title: 'Les produits' };

const NB = new Intl.NumberFormat('fr-FR');
const fmt = (n: number | null) => (n == null ? '—' : NB.format(n));

const MSG_ERREUR = "Impossible de charger les produits. L'API est-elle démarrée ?";

export default async function ProduitsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;
  const terrain = TERRAIN.includes(me.role);

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  let result: Paginated<ArticleRow> | null = null;
  let error: string | null = null;
  try {
    result = await listArticles({ search, page });
  } catch {
    error = MSG_ERREUR;
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Produits</h1>
        <SearchBar placeholder="Libellé, marque, code article, code-barres…" />
      </div>

      {terrain ? <KpisTerrain /> : <KpisEncadrement />}

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
          <Pagination total={result.total} page={result.page} limit={result.limit} params={{ search }} />
        </>
      )}
    </div>
  );
}

/** KPIs terrain : références, promos en cours, mises en avant actives, rappels. */
async function KpisTerrain() {
  const [total, rappels, promos, pem] = await Promise.all([
    countArticles({}),
    countArticles({ rappel: true }),
    listPromosActives(),
    listPem({ actifsSeulement: true }),
  ]);
  return (
    <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <StatTile icon={Boxes} label="Références" value={fmt(total)} />
      <StatTile icon={BadgePercent} label="Promos actives" value={fmt(promos?.length ?? null)} />
      <StatTile icon={Star} label="Mises en avant" value={fmt(pem?.length ?? null)} />
      <StatTile icon={PackageX} label="En rappel" value={fmt(rappels)} />
    </section>
  );
}

/**
 * Bandeau KPI encadrement : uniquement des chiffres réels de l'API. Les évolutions « vs mois dernier » et les
 * ventes moyennes mensuelles ont été retirées : l'API ne fournit ni historique du catalogue ni ventes par produit.
 */
async function KpisEncadrement() {
  const [total, actifs, rappels] = await Promise.all([
    countArticles({}),
    countArticles({ actif: true }),
    countArticles({ rappel: true }),
  ]);
  return (
    <section className="grid grid-cols-2 gap-4 lg:grid-cols-3">
      <KpiTile label="Total produits" info="Références présentes au catalogue" value={fmt(total)} />
      <KpiTile label="Produits actifs" info="Actifs et commandables" value={fmt(actifs)} />
      <KpiTile
        label="En rappel"
        info="Produits à retour autorisé — à contrôler sur le terrain"
        value={fmt(rappels)}
        pill={rappels == null ? undefined : rappels > 0 ? { text: 'à contrôler', tone: 'warn' } : { text: 'aucun', tone: 'up' }}
      />
    </section>
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
