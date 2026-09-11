import { listArticles, type Paginated, type ArticleRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge } from '@/components/badges';

export const metadata = { title: 'Produits — Helios' };

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

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Produits</h1>
        <SearchBar placeholder="Libellé, code article, code-barres…" />
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          <div className="overflow-x-auto rounded-xl bg-white shadow-card">
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
                {result!.data.map((a) => (
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
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">
                      Aucun produit trouvé.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
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
