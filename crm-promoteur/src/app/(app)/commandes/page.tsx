import Link from 'next/link';
import { listCommandes, type CommandesResult, type StatutLivraison } from '@/lib/api';
import { LivraisonBadge, LIVRAISON } from '@/components/livraison-badge';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';

export const metadata = { title: 'Commandes — Selios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });

function StatutBadge({ annulee }: { annulee: boolean }) {
  return annulee ? (
    <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-600">Annulée</span>
  ) : (
    <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-600">Validée</span>
  );
}

export default async function CommandesPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string; annulees?: string; livraison?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const annulees = sp.annulees === 'true';
  const livraison = (Object.keys(LIVRAISON) as StatutLivraison[]).includes(sp.livraison as StatutLivraison)
    ? (sp.livraison as StatutLivraison)
    : undefined;

  /** URL de la page avec un autre filtre de livraison (recherche conservée). */
  const avecLivraison = (statut?: StatutLivraison) => {
    const q = new URLSearchParams();
    if (search) q.set('search', search);
    if (annulees) q.set('annulees', 'true');
    if (statut) q.set('livraison', statut);
    const str = q.toString();
    return str ? `/commandes?${str}` : '/commandes';
  };

  let result: CommandesResult | null = null;
  let error: string | null = null;
  try {
    result = await listCommandes({ search, page, annulees, livraison });
  } catch {
    error = "Impossible de charger les commandes. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{mine ? 'Mes commandes' : 'Commandes'}</h1>
          <p className="text-sm text-neutral-500">
            {mine
              ? `Commandes de mon code représentant (${result!.scope.idRepr}) — remontées de l'ERP Minos.`
              : "Commandes remontées de l'ERP Minos."}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {/* Filtre annulées */}
          <Link
            href={annulees ? '/commandes' : '/commandes?annulees=true'}
            className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition ${
              annulees
                ? 'border-red-300 bg-red-50 text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-400'
                : 'border-neutral-200 text-neutral-500 hover:border-neutral-300 dark:border-navy-700'
            }`}
          >
            {annulees ? '✕ Annulées uniquement' : 'Annulées'}
          </Link>
          <SearchBar placeholder="N° commande, client, code…" />
        </div>
      </div>

      {/* Filtre par statut de livraison (côté API : GET /commandes?livraison=). */}
      <div className="flex flex-wrap items-center gap-1.5 rounded-2xl bg-white p-3 shadow-card">
        <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Livraison</span>
        <Link
          href={avecLivraison()}
          className={`rounded-full border px-3 py-1 text-xs font-medium transition ${
            livraison === undefined
              ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
              : 'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800'
          }`}
        >
          Toutes
        </Link>
        {(Object.keys(LIVRAISON) as StatutLivraison[]).map((statut) => (
          <Link
            key={statut}
            href={avecLivraison(statut)}
            className={`rounded-full border px-3 py-1 text-xs font-medium transition ${
              livraison === statut
                ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
                : 'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800'
            }`}
          >
            {LIVRAISON[statut].label}
          </Link>
        ))}
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          {/* < md : cartes commandes. */}
          <ul className="flex flex-col gap-2.5 md:hidden">
            {result!.data.map((c) => (
              <li key={c.id} className="relative rounded-2xl bg-white p-4 shadow-card">
                <Link href={`/commandes/${c.id}`} className="absolute inset-0" aria-label={`Commande ${c.numero}`} />
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="font-mono text-xs font-medium text-brand dark:text-accent">{c.numero}</p>
                    <p className="mt-0.5 truncate text-sm">
                      {c.client ? c.client.enseigne : (c.raisonSocialeCmd ?? '—')}
                    </p>
                  </div>
                  <span className="flex shrink-0 flex-col items-end gap-1">
                    <StatutBadge annulee={c.annulee} />
                    <LivraisonBadge statut={c.statutLivraison} annulee={c.annulee} />
                  </span>
                </div>
                <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-neutral-500">
                  <span className="font-medium text-neutral-800 dark:text-accent">{EUR.format(c.total)}</span>
                  <span>{c.dateCommande ? DATE_FMT.format(new Date(c.dateCommande)) : '—'}</span>
                  <span>{c.nbLignes} ligne{c.nbLignes > 1 ? 's' : ''}</span>
                  {c.typeCmd ? (
                    <span className="rounded bg-neutral-100 px-1.5 py-0.5 font-mono text-xs dark:bg-navy-800">{c.typeCmd}</span>
                  ) : null}
                </div>
              </li>
            ))}
            {result!.data.length === 0 ? (
              <li className="rounded-2xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
                Aucune commande trouvée.
              </li>
            ) : null}
          </ul>

          {/* ≥ md : tableau. */}
          <div className="hidden overflow-x-auto rounded-xl bg-white shadow-card md:block">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
                <tr>
                  <th className="px-4 py-2.5 font-medium">N°</th>
                  <th className="px-4 py-2.5 font-medium">Date</th>
                  <th className="px-4 py-2.5 font-medium">Client</th>
                  <th className="px-4 py-2.5 font-medium">Type</th>
                  <th className="px-4 py-2.5 text-right font-medium">Lignes</th>
                  <th className="px-4 py-2.5 text-right font-medium">Total</th>
                  <th className="px-4 py-2.5 font-medium">Statut</th>
                  <th className="px-4 py-2.5 font-medium">Livraison</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((c) => (
                  <tr key={c.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-2.5 font-mono text-xs font-medium text-brand dark:text-accent">
                      <Link href={`/commandes/${c.id}`} className="absolute inset-0" aria-label={`Commande ${c.numero}`} />
                      {c.numero}
                    </td>
                    <td className="px-4 py-2.5 text-neutral-500">
                      {c.dateCommande ? DATE_FMT.format(new Date(c.dateCommande)) : '—'}
                    </td>
                    <td className="px-4 py-2.5">
                      {c.client ? (
                        <span>
                          {c.client.enseigne}
                          <span className="ml-1.5 font-mono text-xs text-neutral-400">{c.client.codeAs400}</span>
                        </span>
                      ) : (
                        <span className="text-neutral-400">{c.raisonSocialeCmd ?? '—'}</span>
                      )}
                    </td>
                    <td className="px-4 py-2.5">
                      {c.typeCmd ? (
                        <span className="rounded bg-neutral-100 px-1.5 py-0.5 font-mono text-xs text-neutral-500 dark:bg-navy-800">
                          {c.typeCmd}
                        </span>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td className="px-4 py-2.5 text-right text-neutral-500">{c.nbLignes}</td>
                    <td className="px-4 py-2.5 text-right font-medium dark:text-accent">{EUR.format(c.total)}</td>
                    <td className="px-4 py-2.5">
                      <StatutBadge annulee={c.annulee} />
                    </td>
                    <td className="px-4 py-2.5">
                      <LivraisonBadge statut={c.statutLivraison} annulee={c.annulee} />
                    </td>
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="px-4 py-8 text-center text-neutral-400">
                      Aucune commande trouvée.
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
            params={{ search, ...(annulees ? { annulees: 'true' } : {}), ...(livraison ? { livraison } : {}) }}
          />
        </>
      )}
    </div>
  );
}
