import Link from 'next/link';
import { Camera, Star } from 'lucide-react';
import { listVisites, type VisitesResult } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';

export const metadata = { title: 'Historique de visites — Selios' };

const DATE = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });

function jours(iso: string): number {
  return Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
}

export default async function VisitesPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  let result: VisitesResult | null = null;
  let error: string | null = null;
  try {
    result = await listVisites({ search, page });
  } catch {
    error = "Impossible de charger les visites. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type !== 'global';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{mine ? 'Historique de visites' : 'Visites'}</h1>
          <p className="text-sm text-neutral-500">
            {mine
              ? 'Tes comptes-rendus terrain passés : relevé DN, PEM, photos — saisis sur l’app mobile.'
              : 'Les comptes-rendus terrain de toute la force de vente : relevé DN, PEM, photos.'}
          </p>
        </div>
        <SearchBar placeholder="Magasin, ville, code…" />
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : result!.data.length === 0 ? (
        <p className="rounded-2xl bg-white px-5 py-10 text-center text-sm text-neutral-400 shadow-card">
          Aucune visite enregistrée pour le moment.
        </p>
      ) : (
        <>
          {/* < md : cartes visites. */}
          <ul className="flex flex-col gap-2.5 md:hidden">
            {result!.data.map((v) => (
              <li key={v.id} className="relative rounded-2xl bg-white p-4 shadow-card">
                {v.client ? (
                  <Link href={`/clients/${v.client.id}`} className="absolute inset-0" aria-label={`Fiche ${v.client.enseigne}`} />
                ) : null}
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate font-medium text-brand dark:text-accent">{v.client?.enseigne ?? '—'}</p>
                    <p className="text-[11px] text-neutral-400">
                      {DATE.format(new Date(v.createdAt))} · il y a {jours(v.createdAt)} j
                      {v.client?.ville ? ` · ${v.client.ville}` : ''}
                    </p>
                  </div>
                  {v.pem ? (
                    <span className="inline-flex shrink-0 items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-600 dark:bg-amber-500/15">
                      <Star size={11} /> PEM
                    </span>
                  ) : null}
                </div>
                <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-neutral-500">
                  {!mine && v.promoteur ? <span className="font-medium">{v.promoteur.displayName}</span> : null}
                  {v.motif ? <span>{v.motif}</span> : null}
                  <span>
                    DN <span className="font-semibold text-brand dark:text-accent">{v.dnAbc ?? '—'}</span>
                    {' / conc. '}{v.dnConcurrence ?? '—'}
                  </span>
                  {v._count.photos > 0 ? (
                    <span className="inline-flex items-center gap-1"><Camera size={13} /> {v._count.photos}</span>
                  ) : null}
                </div>
              </li>
            ))}
          </ul>

          {/* ≥ md : tableau. */}
          <div className="hidden overflow-x-auto rounded-2xl bg-white shadow-card md:block">
            <table className="w-full min-w-[820px] text-sm">
              <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Magasin</th>
                  {!mine ? <th className="px-4 py-2.5 font-medium">Promoteur</th> : null}
                  <th className="px-4 py-2.5 font-medium">Date</th>
                  <th className="px-4 py-2.5 font-medium">Motif</th>
                  <th className="px-4 py-2.5 text-right font-medium">DN ABC</th>
                  <th className="px-4 py-2.5 text-right font-medium">DN conc.</th>
                  <th className="px-4 py-2.5 text-center font-medium">PEM</th>
                  <th className="px-4 py-2.5 text-center font-medium">Photos</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((v) => (
                  <tr key={v.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-3">
                      {v.client ? (
                        <Link href={`/clients/${v.client.id}`} className="absolute inset-0" aria-label={`Fiche ${v.client.enseigne}`} />
                      ) : null}
                      <div className="font-medium text-brand dark:text-accent">{v.client?.enseigne ?? '—'}</div>
                      <div className="text-[11px] text-neutral-400">{v.client?.ville ?? ''}</div>
                    </td>
                    {!mine ? (
                      <td className="px-4 py-3 text-neutral-600 dark:text-neutral-300">
                        {v.promoteur?.displayName ?? '—'}
                      </td>
                    ) : null}
                    <td className="px-4 py-3">
                      <div>{DATE.format(new Date(v.createdAt))}</div>
                      <div className="text-[11px] text-neutral-400">il y a {jours(v.createdAt)} j</div>
                    </td>
                    <td className="px-4 py-3">
                      <span className="text-neutral-600 dark:text-neutral-300">{v.motif ?? '—'}</span>
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-brand dark:text-accent">{v.dnAbc ?? '—'}</td>
                    <td className="px-4 py-3 text-right">{v.dnConcurrence ?? '—'}</td>
                    <td className="px-4 py-3 text-center">
                      {v.pem ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-600 dark:bg-amber-500/15">
                          <Star size={11} /> oui
                        </span>
                      ) : (
                        <span className="text-neutral-300">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-center">
                      {v._count.photos > 0 ? (
                        <span className="inline-flex items-center gap-1 text-neutral-500">
                          <Camera size={13} /> {v._count.photos}
                        </span>
                      ) : (
                        <span className="text-neutral-300">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination total={result!.total} page={result!.page} limit={result!.limit} params={{ search }} />
        </>
      )}
    </div>
  );
}
