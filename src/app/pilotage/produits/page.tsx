import { listArticles, countArticles, type Paginated, type ArticleRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { KpiTile } from '@/components/kpi-tile';
import { ProduitsTable } from '@/components/produits-table';

export const metadata = { title: 'Produits — Helios' };

const NB = new Intl.NumberFormat('fr-FR');
const fmt = (n: number | null) => (n == null ? '—' : NB.format(n));

export default async function ProduitsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  let result: Paginated<ArticleRow> | null = null;
  let error: string | null = null;
  try {
    result = await listArticles({ search, page });
  } catch {
    error = "Impossible de charger les produits. L'API est-elle démarrée ?";
  }

  // KPIs catalogue (vrais totaux via les filtres de /articles).
  const [total, actifs, rappels] = await Promise.all([
    countArticles({}),
    countArticles({ actif: true }),
    countArticles({ rappel: true }),
  ]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Produits</h1>
        <SearchBar placeholder="Libellé, code article, code-barres…" />
      </div>

      {/* Bandeau KPI du catalogue — chiffres réels, évolutions « vs mois dernier » illustratives */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile
          label="Total produits"
          info="Références présentes au catalogue"
          value={fmt(total)}
          sub="vs mois dernier"
          pill={{ text: '↑ 3', tone: 'up' }}
        />
        <KpiTile
          label="Produits actifs"
          info="Actifs et commandables"
          value={fmt(actifs)}
          sub="vs mois dernier"
          pill={{ text: '↑ 2%', tone: 'up' }}
        />
        <KpiTile
          label="En rappel"
          info="Produits à retour autorisé — à contrôler sur le terrain"
          value={fmt(rappels)}
          pill={rappels == null ? undefined : rappels > 0 ? { text: 'à contrôler', tone: 'warn' } : { text: 'aucun', tone: 'up' }}
        />
        <KpiTile
          label="Avg. ventes mensuelles"
          info="Moyenne mensuelle des ventes (donnée d'illustration)"
          value="890"
          sub="vs mois dernier"
          pill={{ text: '↑ 5%', tone: 'up' }}
        />
      </section>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          <ProduitsTable articles={result!.data} />
          <Pagination
            total={result!.total}
            page={result!.page}
            limit={result!.limit}
            params={{ search }}
          />
        </>
      )}
    </div>
  );
}
