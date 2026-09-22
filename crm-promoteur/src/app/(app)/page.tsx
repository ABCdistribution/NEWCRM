import Link from 'next/link';
import {
  Wallet,
  ShoppingCart,
  Footprints,
  Store,
  Trophy,
  ChevronLeft,
  ChevronRight,
  TrendingUp,
  TrendingDown,
  PackageX,
} from 'lucide-react';
import { getPerformances, getDashboard } from '@/lib/api';
import { GaugeCard } from '@/components/gauge-card';
import { StatTile } from '@/components/stat-tile';
import { CaChart } from '@/components/ca-chart';
import { CommandesParPromoteur } from '@/components/commandes-par-promoteur';
import { PackageSearch, Users2 } from 'lucide-react';

export const metadata = { title: 'Accueil — Selios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const MOIS_LABELS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const card = 'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold text-brand dark:text-accent';

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ annee?: string; mois?: string }>;
}) {
  const sp = await searchParams;
  const now = new Date();
  const annee = Number(sp.annee) || now.getFullYear();
  const mois = Math.min(12, Math.max(1, Number(sp.mois) || now.getMonth() + 1));

  const prev = mois === 1 ? { annee: annee - 1, mois: 12 } : { annee, mois: mois - 1 };
  const next = mois === 12 ? { annee: annee + 1, mois: 1 } : { annee, mois: mois + 1 };

  const [perf, dash] = await Promise.all([getPerformances(annee, mois), getDashboard()]);

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Mes performances</h1>

        {/* Sélecteur de mois */}
        <div className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
          <Link
            href={`/?annee=${prev.annee}&mois=${prev.mois}`}
            className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
            aria-label="Mois précédent"
          >
            <ChevronLeft size={16} />
          </Link>
          <span className="min-w-36 text-center text-sm font-medium">
            {MOIS_LABELS[mois - 1]} {annee}
          </span>
          <Link
            href={`/?annee=${next.annee}&mois=${next.mois}`}
            className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
            aria-label="Mois suivant"
          >
            <ChevronRight size={16} />
          </Link>
        </div>
      </div>

      {!perf ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          Chiffres indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : perf.noRepr ? (
        <div className="rounded-2xl border border-dashed border-neutral-300 p-10 text-center dark:border-navy-700">
          <p className="font-medium text-neutral-500">Compte non relié à l&apos;ERP</p>
          <p className="mt-1 text-sm text-neutral-400">
            Aucun code représentant n&apos;est associé à ton compte Active Directory — tes chiffres ne
            peuvent pas être calculés. Rapproche-toi de l&apos;administrateur.
          </p>
        </div>
      ) : (
        <>
          {/* KPI du mois */}
          <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <GaugeCard
              icon={Wallet}
              label="CA du mois vs objectif"
              realiseLabel={EUR.format(perf.kpis.ca)}
              cibleLabel={perf.objectif.cible != null ? EUR.format(perf.objectif.cible) : undefined}
              pct={perf.objectif.tauxPct}
            />
            <StatTile
              icon={ShoppingCart}
              label="Commandes"
              value={String(perf.kpis.commandes)}
              hint={perf.kpis.commandes > 0 ? `Panier moyen ${EUR.format(perf.kpis.panierMoyen)}` : 'Aucune commande ce mois'}
            />
            <StatTile
              icon={Footprints}
              label="Visites"
              value={String(perf.kpis.visites)}
              hint="Alimenté par l'app mobile"
            />
            <StatTile
              icon={Store}
              label="Couverture portefeuille"
              value={`${perf.couverture.commandants}/${perf.couverture.portefeuille}`}
              hint={`${perf.couverture.sansCommande} magasin${perf.couverture.sansCommande > 1 ? 's' : ''} sans commande ce mois`}
            />
          </section>

          {/* Delta N-1 + rang */}
          <section className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className={`${card} flex items-center gap-4 px-5 py-4`}>
              {perf.kpis.deltaPct == null ? (
                <>
                  <TrendingUp size={22} className="text-neutral-300" />
                  <div>
                    <p className="text-sm font-medium">Évolution vs {perf.periode.annee - 1}</p>
                    <p className="text-xs text-neutral-400">
                      Pas de référence {MOIS_LABELS[perf.periode.mois - 1].toLowerCase()} {perf.periode.annee - 1} (historique non importé).
                    </p>
                  </div>
                </>
              ) : perf.kpis.deltaPct >= 0 ? (
                <>
                  <TrendingUp size={22} className="text-emerald-500" />
                  <div>
                    <p className="text-sm font-medium">
                      <span className="text-emerald-600">+{perf.kpis.deltaPct}%</span> vs{' '}
                      {MOIS_LABELS[perf.periode.mois - 1].toLowerCase()} {perf.periode.annee - 1}
                    </p>
                    <p className="text-xs text-neutral-400">{EUR.format(perf.kpis.caN1)} l&apos;an dernier</p>
                  </div>
                </>
              ) : (
                <>
                  <TrendingDown size={22} className="text-red-500" />
                  <div>
                    <p className="text-sm font-medium">
                      <span className="text-red-600">{perf.kpis.deltaPct}%</span> vs{' '}
                      {MOIS_LABELS[perf.periode.mois - 1].toLowerCase()} {perf.periode.annee - 1}
                    </p>
                    <p className="text-xs text-neutral-400">{EUR.format(perf.kpis.caN1)} l&apos;an dernier</p>
                  </div>
                </>
              )}
            </div>

            <div className={`${card} flex items-center gap-4 px-5 py-4`}>
              <Trophy size={22} className="text-amber-500" />
              <div>
                <p className="text-sm font-medium text-brand dark:text-accent">
                  {perf.rang.position != null ? (
                    <>
                      {perf.rang.position}
                      <sup>{perf.rang.position === 1 ? 'er' : 'e'}</sup> / {perf.rang.total} commerciaux ce mois
                    </>
                  ) : (
                    'Rang indisponible'
                  )}
                </p>
                <p className="text-xs text-neutral-400">
                  Classement par CA facturé (code {perf.idRepr}) — détail complet dans helios.
                </p>
              </div>
            </div>
          </section>

          {/* Courbe CA 12 mois */}
          <section className={card}>
            <h2 className={cardHeader}>
              <Wallet size={17} className="text-brand dark:text-accent" />
              Mon CA mensuel — {perf.ca12mois.anneeN - 1} vs {perf.ca12mois.anneeN}
            </h2>
            <CaChart anneeN={perf.ca12mois.anneeN} courbeN={perf.ca12mois.courbeN} courbeN1={perf.ca12mois.courbeN1} />
          </section>

          <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
            {/* Top magasins */}
            <section className={card}>
              <h2 className={cardHeader}>
                <Store size={17} className="text-brand dark:text-accent" />
                Top de mes magasins — {MOIS_LABELS[perf.periode.mois - 1]}
              </h2>
              {perf.topMagasins.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">Aucune commande ce mois.</p>
              ) : (
                <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                  {perf.topMagasins.map((m, i) => (
                    <li key={m.id} className="flex items-center gap-3 px-5 py-3">
                      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-semibold text-neutral-500 dark:bg-navy-800">
                        {i + 1}
                      </span>
                      <Link href={`/clients/${m.id}`} className="min-w-0 flex-1 truncate text-sm font-medium text-brand hover:underline dark:text-accent">
                        {m.enseigne}
                      </Link>
                      <span className="shrink-0 text-xs text-neutral-400">
                        {m.nb} cmd{m.nb > 1 ? 's' : ''}
                      </span>
                      <span className="shrink-0 text-sm font-semibold text-brand dark:text-accent">{EUR.format(m.ca)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>

            {/* Magasins sans commande */}
            <section className={card}>
              <h2 className={cardHeader}>
                <PackageX size={17} className="text-amber-500" />
                À relancer — sans commande ce mois
                <span className="ml-auto rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-600">
                  {perf.couverture.sansCommande}
                </span>
              </h2>
              {perf.couverture.exemplesSansCommande.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">
                  🎉 Tous les magasins du portefeuille ont commandé ce mois.
                </p>
              ) : (
                <>
                  <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                    {perf.couverture.exemplesSansCommande.map((c) => (
                      <li key={c.id} className="flex items-center gap-3 px-5 py-3">
                        <Link href={`/clients/${c.id}`} className="min-w-0 flex-1 truncate text-sm font-medium text-brand hover:underline dark:text-accent">
                          {c.nom}
                        </Link>
                        {c.ville ? <span className="shrink-0 text-xs text-neutral-400">{c.ville}</span> : null}
                      </li>
                    ))}
                  </ul>
                  {perf.couverture.sansCommande > perf.couverture.exemplesSansCommande.length ? (
                    <p className="border-t border-neutral-100 px-5 py-2.5 text-xs text-neutral-400 dark:border-navy-700">
                      … et {perf.couverture.sansCommande - perf.couverture.exemplesSansCommande.length} autres.
                    </p>
                  ) : null}
                </>
              )}
            </section>
          </div>
        </>
      )}

      {dash ? (
        <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
          {/* Magasins ayant commandé ce mois, par promoteur */}
          <section className="rounded-2xl bg-white shadow-card">
            <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3.5 text-sm font-semibold dark:border-navy-700">
              <Users2 size={16} className="text-brand dark:text-accent" />
              Magasins ayant commandé ce mois — par promoteur
            </h2>
            <CommandesParPromoteur groupes={dash.commandesParPromoteur ?? []} />
          </section>

          {/* Commandes à suivre / relancer */}
          <section className="rounded-2xl bg-white shadow-card">
            <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3.5 text-sm font-semibold dark:border-navy-700">
              <PackageSearch size={16} className="text-brand dark:text-accent" />
              Commandes à suivre
              <span className="ml-auto text-xs font-normal text-neutral-400">{(dash.commandesASuivre ?? []).length}</span>
            </h2>
            {(dash.commandesASuivre ?? []).length === 0 ? (
              <p className="px-5 py-6 text-sm text-neutral-400">Aucune commande en attente de livraison.</p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {dash.commandesASuivre.map((c) => (
                  <li key={c.id}>
                    <Link href={`/commandes/${c.id}`} className="flex items-center gap-3 px-5 py-2.5 transition hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                      <span className={`h-2 w-2 shrink-0 rounded-full ${c.enRetard ? 'bg-red-400' : 'bg-amber-400'}`} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">{c.magasin}</p>
                        <p className="text-xs text-neutral-400">
                          {c.numero}
                          {c.dateCommande ? ` · ${new Date(c.dateCommande).toLocaleDateString('fr-FR')}` : ''}
                        </p>
                      </div>
                      <span className={`shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                        c.enRetard
                          ? 'bg-red-500/12 text-red-500'
                          : c.statut === 'EN_PREPARATION'
                            ? 'bg-amber-500/12 text-amber-600 dark:text-amber-400'
                            : 'bg-sky-500/12 text-sky-600 dark:text-sky-400'
                      }`}>
                        {c.enRetard ? 'À relancer' : c.statut === 'EN_PREPARATION' ? 'En préparation' : 'Expédiée'}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      ) : null}
    </div>
  );
}

