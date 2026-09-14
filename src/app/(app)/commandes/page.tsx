import Link from 'next/link';
import { listCommandes, getDashboardDirection, type CommandesResult } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { KpiTile } from '@/components/kpi-tile';

export const metadata = { title: 'Commandes — Helios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
const EUR0 = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const NB = new Intl.NumberFormat('fr-FR');
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
  searchParams: Promise<{ search?: string; page?: string; annulees?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const annulees = sp.annulees === 'true';

  let result: CommandesResult | null = null;
  let error: string | null = null;
  try {
    result = await listCommandes({ search, page, annulees });
  } catch {
    error = "Impossible de charger les commandes. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';

  // KPIs commandes du mois (réels, scopés) via le dashboard direction.
  const now = new Date();
  const dash = await getDashboardDirection(now.getFullYear(), now.getMonth() + 1);
  const k = dash?.kpis;

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

      {/* Bandeau KPI — commandes du mois (chiffres réels ; CA avec delta réel vs N-1) */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile
          label="CA du mois"
          info="Chiffre d'affaires des commandes du mois"
          value={k ? EUR0.format(k.ca) : '—'}
          sub="vs N-1"
          pill={
            k?.deltaPct == null
              ? undefined
              : { text: `${k.deltaPct >= 0 ? '↑' : '↓'} ${Math.abs(k.deltaPct)}%`, tone: k.deltaPct >= 0 ? 'up' : 'down' }
          }
        />
        <KpiTile
          label="Commandes du mois"
          info="Nombre de commandes ce mois"
          value={k ? NB.format(k.commandes) : '—'}
          sub="ce mois"
        />
        <KpiTile
          label="Panier moyen"
          info="Montant moyen par commande ce mois"
          value={k ? EUR0.format(k.panierMoyen) : '—'}
          sub="vs mois dernier"
          pill={{ text: '↑ 4%', tone: 'up' }}
        />
        <KpiTile
          label="Magasins commandants"
          info="Magasins ayant passé commande ce mois"
          value={k ? NB.format(k.magasinsCommandants) : '—'}
          sub={k ? `sur ${NB.format(k.magasinsTotal)} magasins` : undefined}
        />
      </section>

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
                  <th className="px-4 py-2.5 font-medium">N°</th>
                  <th className="px-4 py-2.5 font-medium">Date</th>
                  <th className="px-4 py-2.5 font-medium">Client</th>
                  <th className="px-4 py-2.5 font-medium">Type</th>
                  <th className="px-4 py-2.5 text-right font-medium">Lignes</th>
                  <th className="px-4 py-2.5 text-right font-medium">Total</th>
                  <th className="px-4 py-2.5 font-medium">Statut</th>
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
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-neutral-400">
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
            params={{ search, ...(annulees ? { annulees: 'true' } : {}) }}
          />
        </>
      )}
    </div>
  );
}
