import type { ArticleRow } from '@/lib/api';
import { ActiveBadge } from './badges';
import { LienProduit } from './produit-lien';

/**
 * Catalogue côté terrain : cartes sous md, tableau au-dessus. Chaque carte et chaque ligne ouvre la fiche du produit
 * (`/produits/[id]`) par le lien du libellé. Composant serveur : aucun état.
 */
export function CatalogueTerrain({ articles }: { articles: ArticleRow[] }) {
  return (
    <>
      <ul className="flex flex-col gap-2.5 md:hidden">
        {articles.map((a) => (
          <li key={a.id} className="relative rounded-2xl bg-white p-4 shadow-card">
            <div className="flex items-start justify-between gap-2">
              <p className="min-w-0 text-sm font-medium">
                <LienProduit id={a.id} libelle={a.libelle} rayon="after:rounded-2xl" />
              </p>
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
              <th scope="col" className="px-4 py-2.5 font-medium">Code</th>
              <th scope="col" className="px-4 py-2.5 font-medium">Libellé</th>
              <th scope="col" className="px-4 py-2.5 font-medium">Marque</th>
              <th scope="col" className="px-4 py-2.5 font-medium">Gamme</th>
              <th scope="col" className="px-4 py-2.5 font-medium">PCB</th>
              <th scope="col" className="px-4 py-2.5 font-medium">Statut</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {articles.map((a) => (
              <tr key={a.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-2.5 font-mono text-xs">{a.codeAs400}</td>
                <td className="px-4 py-2.5">
                  <LienProduit id={a.id} libelle={a.libelle} />
                </td>
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
