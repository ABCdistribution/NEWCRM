import { PackageX } from 'lucide-react';
import { listArticles, type Paginated, type ArticleRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';

export const metadata = { title: 'Qualité & Rappels Produits — Helios' };

export default async function QualitePage({
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
    result = await listArticles({ search, page, rappel: true });
  } catch {
    error = "Impossible de charger les rappels. L'API est-elle démarrée ?";
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Qualité &amp; Rappels Produits</h1>
        </div>
        <SearchBar placeholder="Libellé, code article…" />
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          <div className="flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-400">
            <PackageX size={18} />
            <span>
              <strong>{result!.total}</strong> produit{result!.total > 1 ? 's' : ''} en rappel
              {search ? ' (filtré)' : ''}.
            </span>
          </div>

          <div className="overflow-x-auto rounded-xl bg-white shadow-card">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Code</th>
                  <th className="px-4 py-2.5 font-medium">Libellé</th>
                  <th className="px-4 py-2.5 font-medium">Marque</th>
                  <th className="px-4 py-2.5 font-medium">Statut</th>
                  <th className="px-4 py-2.5 font-medium">État</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((a) => (
                  <tr key={a.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-2.5 font-mono text-xs">{a.codeAs400}</td>
                    <td className="px-4 py-2.5">{a.libelle}</td>
                    <td className="px-4 py-2.5">{a.marque?.nom ?? '—'}</td>
                    <td className="px-4 py-2.5">{a.statut ?? '—'}</td>
                    <td className="px-4 py-2.5">
                      <span className="inline-flex items-center gap-1 rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-600">
                        <PackageX size={12} />
                        Rappel
                      </span>
                    </td>
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-neutral-400">
                      Aucun produit en rappel.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          <Pagination total={result!.total} page={result!.page} limit={result!.limit} params={{ search }} />
        </>
      )}
    </div>
  );
}
