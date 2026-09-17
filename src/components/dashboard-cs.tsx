import Link from 'next/link';
import { SeliosLink } from './selios-link';
import {
  Wallet,
  Store,
  Target,
  PackageX,
  TrendingDown,
  Route,
  ArrowRight,
  Users,
} from 'lucide-react';
import { StatTile } from '@/components/stat-tile';
import { ClassBadge } from '@/components/class-badge';
import { CaChart } from '@/components/ca-chart';
import { DonutChart } from '@/components/donut-chart';
import type { DashboardDirection } from '@/lib/api';
import { ProspectionObjectifCard } from './prospection-objectif-card';

const EUR = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

const card = 'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700';

/**
 * Tableau de bord dédié au chef de secteur.
 * Rendu à partir de /dashboard/direction, déjà scopé sur le secteur du CS par l'API.
 * Orienté action : ce qu'il faut traiter (sans commande, en baisse) avant la performance brute.
 */
export function DashboardCS({ data }: { data: DashboardDirection }) {
  const enBaisse = data.classement
    .filter((p) => p.deltaPct != null && p.deltaPct < 0)
    .sort((a, b) => (a.deltaPct ?? 0) - (b.deltaPct ?? 0))
    .slice(0, 6);

  const equipe = [...data.classement].sort((a, b) => b.ca - a.ca);

  return (
    <div className="flex flex-col gap-5">
      {/* KPIs du secteur */}
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatTile
          icon={Wallet}
          label="CA du mois"
          value={EUR.format(data.kpis.ca)}
          hint={
            data.kpis.deltaPct != null
              ? `${data.kpis.deltaPct >= 0 ? '+' : ''}${data.kpis.deltaPct}% vs N-1`
              : 'Pas de référence N-1'
          }
        />
        <StatTile
          icon={Store}
          label="Magasins commandants"
          value={`${data.kpis.magasinsCommandants}/${data.kpis.magasinsTotal}`}
          hint={`${data.sansCommande.total} sans commande ce mois`}
        />
        <StatTile
          icon={Target}
          label="Objectifs atteints"
          value={`${data.objectifs.atteints}/${data.objectifs.definis}`}
          hint={
            data.objectifs.sansObjectif > 0
              ? `${data.objectifs.sansObjectif} sans objectif`
              : 'Tous les promoteurs ont un objectif'
          }
        />
        <StatTile
          icon={Users}
          label="Mon équipe"
          value={String(data.classement.length)}
          hint={`${equipe.filter((p) => p.isActive).length} promoteur(s) actif(s)`}
        />
      </section>

      {/* Graphes : CA 12 mois + couverture */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <section className={`${card} xl:col-span-2`}>
          <h2 className={cardHeader}>
            <Wallet size={17} className="text-brand dark:text-accent" />
            CA mensuel — {data.ca12mois.anneeN - 1} vs {data.ca12mois.anneeN}
          </h2>
          <CaChart anneeN={data.ca12mois.anneeN} courbeN={data.ca12mois.courbeN} courbeN1={data.ca12mois.courbeN1} />
        </section>
        <section className={card}>
          <h2 className={cardHeader}>
            <Store size={17} className="text-brand dark:text-accent" />
            Couverture du mois
          </h2>
          <DonutChart
            segments={[
              { label: 'Ont commandé', value: data.kpis.magasinsCommandants, color: '#10b981' },
              { label: 'Sans commande', value: Math.max(0, data.kpis.magasinsTotal - data.kpis.magasinsCommandants), color: '#f59e0b' },
            ]}
            centerValue={
              data.kpis.magasinsTotal > 0
                ? `${Math.round((data.kpis.magasinsCommandants / data.kpis.magasinsTotal) * 100)}%`
                : '—'
            }
            centerLabel="couverture"
          />
        </section>
      </div>

      {/* À traiter : les deux signaux les plus actionnables pour un CS */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
        {/* Sans commande */}
        <section className={card}>
          <h2 className={cardHeader}>
            <PackageX size={17} className="text-amber-400" />
            À relancer — sans commande ce mois
            <span className="ml-auto rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-500">
              {data.sansCommande.total}
            </span>
          </h2>
          {data.sansCommande.exemples.length === 0 ? (
            <p className="px-5 py-6 text-sm text-neutral-400">
              🎉 Tous les magasins actifs du secteur ont commandé.
            </p>
          ) : (
            <>
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {data.sansCommande.exemples.map((c) => (
                  <li key={c.id} className="flex items-center gap-3 px-5 py-2.5">
                    <Link
                      href={`/pilotage/clients/${c.id}`}
                      className="min-w-0 flex-1 truncate text-sm font-medium text-brand hover:underline dark:text-accent"
                    >
                      {c.nom}
                    </Link>
                    <ClassBadge value={c.niveauClass} size="xs" />
                    {c.ville ? (
                      <span className="shrink-0 text-xs text-neutral-400">{c.ville}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
              <div className="flex items-center justify-between border-t border-neutral-100 px-5 py-2.5 text-xs dark:border-navy-700">
                <span className="text-neutral-400">
                  {data.sansCommande.total > data.sansCommande.exemples.length
                    ? `… et ${data.sansCommande.total - data.sansCommande.exemples.length} autres`
                    : 'Liste complète des magasins'}
                </span>
                <SeliosLink
                  path="/planification"
                  className="inline-flex items-center gap-1 font-medium text-brand hover:underline dark:text-accent"
                >
                  Planifier une tournée <Route size={13} />
                </SeliosLink>
              </div>
            </>
          )}
        </section>

        {/* En baisse */}
        <section className={card}>
          <h2 className={cardHeader}>
            <TrendingDown size={17} className="text-red-400" />
            Promoteurs en baisse vs N-1
            <span className="ml-auto rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-semibold text-red-400">
              {data.classement.filter((p) => p.deltaPct != null && p.deltaPct < 0).length}
            </span>
          </h2>
          {enBaisse.length === 0 ? (
            <p className="px-5 py-6 text-sm text-neutral-400">
              Aucun promoteur en recul ce mois. 👍
            </p>
          ) : (
            <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
              {enBaisse.map((p) => (
                <li key={`${p.idRepr}-${p.userId ?? 'x'}`} className="flex items-center gap-3 px-5 py-2.5">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{p.nom}</p>
                    <p className="font-mono text-[11px] text-neutral-400">code {p.idRepr}</p>
                  </div>
                  <span className="shrink-0 text-sm font-semibold dark:text-accent">{EUR.format(p.ca)}</span>
                  <span className="inline-flex shrink-0 items-center gap-1 text-xs font-semibold text-red-400">
                    <TrendingDown size={13} />
                    {p.deltaPct}%
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      {/* Mon équipe (classement du secteur) */}
      {/* CA réalisé vs objectif côté prospection */}
      <ProspectionObjectifCard p={data.prospection} />

      <section className={card}>
        <h2 className={cardHeader}>
          <Users size={17} className="text-brand dark:text-accent" />
          Mon équipe — performance du mois
        </h2>
        {equipe.length === 0 ? (
          <p className="px-5 py-6 text-sm text-neutral-400">Aucun promoteur relié au secteur.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-xs text-neutral-400">
                <tr>
                  <th className="px-5 py-2 font-medium">Promoteur</th>
                  <th className="px-2 py-2 text-right font-medium">CA</th>
                  <th className="px-2 py-2 text-right font-medium">vs N-1</th>
                  <th className="px-5 py-2 text-right font-medium">Objectif</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {equipe.map((p) => (
                  <tr key={`${p.idRepr}-${p.userId ?? 'x'}`} className={p.isActive ? '' : 'opacity-50'}>
                    <td className="px-5 py-2.5">
                      <p className="font-medium">{p.nom}</p>
                      <p className="font-mono text-[11px] text-neutral-400">code {p.idRepr}</p>
                    </td>
                    <td className="px-2 py-2.5 text-right font-semibold dark:text-accent">{EUR.format(p.ca)}</td>
                    <td className="px-2 py-2.5 text-right">
                      {p.deltaPct == null ? (
                        <span className="text-xs text-neutral-400">n/d</span>
                      ) : (
                        <span className={`text-xs font-semibold ${p.deltaPct >= 0 ? 'text-emerald-500' : 'text-red-400'}`}>
                          {p.deltaPct >= 0 ? '+' : ''}
                          {p.deltaPct}%
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-2.5 text-right">
                      {p.tauxPct == null ? (
                        <span className="text-xs text-neutral-400">—</span>
                      ) : (
                        <span
                          className={`text-xs font-semibold ${
                            p.tauxPct >= 100 ? 'text-emerald-500' : p.tauxPct >= 70 ? 'text-amber-400' : 'text-red-400'
                          }`}
                        >
                          {p.tauxPct}%
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* Accès centre d'alertes */}
      <Link
        href="/pilotage/alertes"
        className="flex items-center gap-3 rounded-2xl border border-dashed border-brand/30 bg-brand/5 px-5 py-4 text-sm font-medium text-brand transition hover:bg-brand/10 dark:border-accent/30 dark:bg-accent/5 dark:text-accent dark:hover:bg-accent/10"
      >
        <span className="flex-1">Voir toutes les alertes de mon secteur (rappels, sans commande, baisses)</span>
        <ArrowRight size={16} />
      </Link>
    </div>
  );
}
