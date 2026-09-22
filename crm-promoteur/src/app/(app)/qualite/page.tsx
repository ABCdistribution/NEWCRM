import { PackageX } from 'lucide-react';
import { listArticles, type Paginated, type ArticleRow } from '@/lib/api';
import { RappelsBoard } from '@/components/rappels-board';

export const metadata = { title: 'Qualité & Rappels Produits — Selios' };

export default async function QualitePage() {
  let rappels: Paginated<ArticleRow> | null = null;
  let error: string | null = null;
  try {
    rappels = await listArticles({ page: 1, rappel: true });
  } catch {
    error = "Impossible de charger les produits en rappel. L'API est-elle démarrée ?";
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold">Qualité &amp; Rappels Produits</h1>
      </div>

      {/* Tableau des bordereaux + carte latérale des produits en rappel. */}
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

          {error ? (
            <p className="px-4 py-4 text-xs text-amber-700 dark:text-amber-400">{error}</p>
          ) : rappels!.data.length === 0 ? (
            <p className="px-4 py-6 text-center text-xs text-neutral-400">Aucun produit en rappel actuellement.</p>
          ) : (
            <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
              {rappels!.data.map((a) => (
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
