import { PackageX } from 'lucide-react';
import { listArticles, type ArticleRow, type Paginated } from '@/lib/api';
import { requireRole, TERRAIN, TOUS_ROLES } from '@/lib/roles';
import { RappelsBoard } from '@/components/rappels-board';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';

export const metadata = { title: 'Qualité & rappels produits' };

export default async function QualitePage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const terrain = TERRAIN.includes(acces.me.role);

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  // Terrain : liste latérale (1re page, sans recherche). Encadrement : tableau recherchable paginé.
  let rappels: Paginated<ArticleRow> | null = null;
  let error: string | null = null;
  try {
    rappels = terrain
      ? await listArticles({ page: 1, rappel: true })
      : await listArticles({ search, page, rappel: true });
  } catch {
    error = "Impossible de charger les produits en rappel. L'API est-elle démarrée ?";
  }

  return terrain ? (
    <QualiteTerrain rappels={rappels} error={error} />
  ) : (
    <QualiteEncadrement rappels={rappels} error={error} search={search} />
  );
}

type Props = { rappels: Paginated<ArticleRow> | null; error: string | null };

/** Terrain : bordereaux de retour + carte latérale des produits en rappel. */
function QualiteTerrain({ rappels, error }: Props) {
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold">Qualité &amp; Rappels Produits</h1>

      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_300px]">
        <RappelsBoard />

        <aside className="rounded-2xl bg-white shadow-card xl:sticky xl:top-4">
          <h2 className="flex items-center gap-2 border-b border-neutral-100 px-4 py-3 text-sm font-semibold dark:border-navy-700">
            <PackageX size={15} className="text-red-500" />
            Produits en rappel
            {rappels ? (
              <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-semibold text-red-600">
                {rappels.total}
              </span>
            ) : null}
          </h2>

          {error || !rappels ? (
            <p role="alert" className="px-4 py-4 text-xs text-amber-700 dark:text-amber-400">
              {error ?? "Impossible de charger les produits en rappel."}
            </p>
          ) : rappels.data.length === 0 ? (
            <p className="px-4 py-6 text-center text-xs text-neutral-400">Aucun produit en rappel actuellement.</p>
          ) : (
            <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
              {rappels.data.map((a) => (
                <li key={a.id} className="px-4 py-2.5">
                  <p className="text-sm font-medium leading-snug">{a.libelle}</p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] text-neutral-400">
                    <span className="font-mono">{a.codeAs400}</span>
                    {a.marque?.nom ? <span>{a.marque.nom}</span> : null}
                    {a.statut ? <span>{a.statut}</span> : null}
                  </p>
                </li>
              ))}
            </ul>
          )}

          <p className="border-t border-neutral-100 px-4 py-2.5 text-[11px] text-neutral-400 dark:border-navy-700">
            À contrôler en linéaire à chaque visite : retirer du rayon et joindre au prochain bordereau de retour.
          </p>
        </aside>
      </div>
    </div>
  );
}

/** Encadrement : tableau recherchable des produits en rappel, puis bordereaux de retour. */
function QualiteEncadrement({ rappels, error, search }: Props & { search: string }) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Qualité &amp; Rappels Produits</h1>
        <SearchBar placeholder="Libellé, code article…" />
      </div>

      {error || !rappels ? (
        <p
          role="alert"
          className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300"
        >
          {error ?? 'Impossible de charger les produits en rappel.'}
        </p>
      ) : (
        <>
          <div className="flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-400">
            <PackageX size={18} />
            <span>
              <strong>{rappels.total}</strong> produit{rappels.total > 1 ? 's' : ''} en rappel
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
                {rappels.data.map((a) => (
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
                {rappels.data.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-neutral-400">
                      Aucun produit en rappel.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          <Pagination total={rappels.total} page={rappels.page} limit={rappels.limit} params={{ search }} />
        </>
      )}

      <RappelsBoard />
    </div>
  );
}
