import { BadgePercent, Boxes, PackageX, Star } from 'lucide-react';
import { listArticles, listPromosActives, listPem, type Paginated, type ArticleRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge } from '@/components/badges';
import { StatTile } from '@/components/stat-tile';

export const metadata = { title: 'Produits — Selios' };

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
  // KPIs catalogue (indépendants de la recherche) : total, promos actives, PEM, rappels.
  let totalCatalogue: number | null = null;
  let totalRappels: number | null = null;
  let promosActives: number | null = null;
  let pemActifs: number | null = null;
  try {
    const [r, tous, rappels, promos, pem] = await Promise.all([
      listArticles({ search, page }),
      listArticles({ page: 1 }),
      listArticles({ page: 1, rappel: true }),
      listPromosActives(),
      listPem(),
    ]);
    result = r;
    totalCatalogue = tous.total;
    totalRappels = rappels.total;
    promosActives = promos?.length ?? null;
    pemActifs = pem?.length ?? null;
  } catch {
    error = "Impossible de charger les produits. L'API est-elle démarrée ?";
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Produits</h1>
        <SearchBar placeholder="Libellé, code article, code-barres…" />
      </div>

      {/* KPIs catalogue */}
      {error ? null : (
        <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <StatTile icon={Boxes} label="Références" value={String(totalCatalogue ?? '—')} />
          <StatTile icon={BadgePercent} label="Promos actives" value={String(promosActives ?? '—')} />
          <StatTile icon={Star} label="Mises en avant" value={String(pemActifs ?? '—')} />
          <StatTile icon={PackageX} label="En rappel" value={String(totalRappels ?? '—')} />
        </section>
      )}

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          {/* < md : cartes produits. */}
          <ul className="flex flex-col gap-2.5 md:hidden">
            {result!.data.map((a) => (
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
            {result!.data.length === 0 ? (
              <li className="rounded-2xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
                Aucun produit trouvé.
              </li>
            ) : null}
          </ul>

          {/* ≥ md : tableau. */}
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
