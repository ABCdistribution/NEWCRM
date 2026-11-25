import type { ArticleRow } from '@/lib/api';
import { ActiveBadge } from './badges';
import { LienProduit } from './produit-lien';

/**
 * Liste des produits (vue encadrement). Toute la ligne ouvre la fiche (`/produits/[id]`) par le lien du libellé.
 * Composant serveur : aucun état, que le rendu des lignes déjà filtrées par l'API.
 */
export function ProduitsTable({ articles }: { articles: ArticleRow[] }) {
  return (
    <div className="overflow-x-auto rounded-xl bg-white shadow-card">
      <table className="w-full text-sm">
        <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
          <tr>
            <th scope="col" className="px-4 py-2.5 font-medium">Code</th>
            <th scope="col" className="px-4 py-2.5 font-medium">Libellé</th>
            <th scope="col" className="px-4 py-2.5 font-medium">Marque</th>
            <th scope="col" className="px-4 py-2.5 font-medium">Gamme</th>
            <th scope="col" className="px-4 py-2.5 text-right font-medium">Stock</th>
            <th scope="col" className="px-4 py-2.5 font-medium">Statut</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
          {articles.map((a) => (
            <tr key={a.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
              <td className="px-4 py-2.5 font-mono text-xs">{a.codeAs400}</td>
              <td className="px-4 py-2.5 font-medium">
                <LienProduit id={a.id} libelle={a.libelle} />
              </td>
              <td className="px-4 py-2.5 text-neutral-500">{a.marque?.nom ?? '—'}</td>
              <td className="px-4 py-2.5 text-neutral-500">{a.gamme?.nom ?? '—'}</td>
              <td className={`px-4 py-2.5 text-right tabular-nums ${a.stock <= 0 ? 'font-semibold text-red-600' : ''}`}>{a.stock}</td>
              <td className="px-4 py-2.5"><ActiveBadge active={a.actif} /></td>
            </tr>
          ))}
          {articles.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">Aucun produit trouvé.</td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </div>
  );
}
