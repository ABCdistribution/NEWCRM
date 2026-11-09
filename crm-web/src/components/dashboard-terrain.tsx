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
  PackageSearch,
  UsersRound,
} from 'lucide-react';
import { getPerformances, getDashboard, getEvolutionCa, getVisitesRegions, type Me } from '@/lib/api';
import { estEncadrement } from '@/lib/roles';
import { formatEUR } from '@/lib/format';
import { GaugeCard } from '@/components/gauge-card';
import { StatTile } from '@/components/stat-tile';
import { EvolutionCaCommandes } from '@/components/evolution-ca-commandes';
import { RepartitionVisites } from '@/components/repartition-visites';
import { CommandesParPromoteur } from '@/components/commandes-par-promoteur';

const MOIS_LABELS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const card = 'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold text-brand dark:text-accent';
/** Contour de focus clavier, aux couleurs de l'espace. */
const FOCUS = 'focus-visible:outline-2 focus-visible:outline-brand dark:focus-visible:outline-accent';
/** Lien vers une fiche client (liste « Top » et « À relancer »). */
const LIEN_CLIENT = `min-w-0 flex-1 truncate rounded-sm text-sm font-medium text-brand hover:underline dark:text-accent ${FOCUS}`;

/**
 * Accueil « terrain » (COMMERCIAL / ADV) : « Mes performances » du mois, évolution du CA, répartition
 * des visites, commandes par promoteur et commandes à suivre.
 *
 * Reprend le corps de l'accueil d'ABC Sales (crm-promoteur) sans la redirection par rôle : c'est la page
 * appelante qui choisit ce tableau de bord selon `me.role`. Composant serveur : les chiffres viennent de
 * l'API (serverFetch), déjà filtrés par rôle et périmètre côté API.
 *
 * `annee` et `mois` sont attendus déjà validés par la page (mois entre 1 et 12).
 */
export async function DashboardTerrain({ me, annee, mois }: { me: Me; annee: number; mois: number }) {
  const prev = mois === 1 ? { annee: annee - 1, mois: 12 } : { annee, mois: mois - 1 };
  const next = mois === 12 ? { annee: annee + 1, mois: 1 } : { annee, mois: mois + 1 };

  const [perf, dash, evolution, visitesRegions] = await Promise.all([
    getPerformances(annee, mois),
    getDashboard(),
    getEvolutionCa(annee, mois),
    getVisitesRegions(annee, mois),
  ]);

  // Compte sans code représentant : l'API bascule alors /dashboard/me en vue globale (tous les promoteurs).
  // On n'affiche donc le suivi (clients par promoteur, commandes à suivre) que pour un compte relié, c'est-à-dire
  // quand les performances existent et ne sont pas « noRepr ». Affichage seulement : le périmètre vide
  // d'un compte sans code est à fournir par l'API.
  const suivi = perf && !perf.noRepr ? dash : null;
  const aSuivre = suivi?.commandesASuivre ?? [];

  // Évolution du CA / des commandes sur 6 mois + répartition des visites par région.
  const graphiques =
    evolution || visitesRegions ? (
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-5">
        {evolution ? (
          <div className="xl:col-span-3">
            <EvolutionCaCommandes mois={evolution.mois} />
          </div>
        ) : null}
        {visitesRegions ? (
          <div className="xl:col-span-2">
            <RepartitionVisites
              regions={visitesRegions.regions}
              total={visitesRegions.total}
              moisLabel={`${MOIS_LABELS[mois - 1]} ${annee}`}
            />
          </div>
        ) : null}
      </div>
    ) : null;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Mes performances</h1>

        {/* Sélecteur de mois */}
        <nav aria-label="Choix du mois" className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
          <Link
            href={`/?annee=${prev.annee}&mois=${prev.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label="Mois précédent"
          >
            <ChevronLeft size={16} />
          </Link>
          <span className="min-w-36 text-center text-sm font-medium">
            {MOIS_LABELS[mois - 1]} {annee}
          </span>
          <Link
            href={`/?annee=${next.annee}&mois=${next.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label="Mois suivant"
          >
            <ChevronRight size={16} />
          </Link>
        </nav>
      </div>

      {!perf ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          Chiffres indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : perf.noRepr ? (
        <>
          <div className="rounded-2xl border border-dashed border-neutral-300 p-10 text-center dark:border-navy-700">
            {me.role === 'ADV' ? (
              // ADV : pas de code représentant par nature (accueil de ce rôle à définir) : message neutre, sans « compte non relié ».
              <>
                <p className="font-medium text-neutral-500">Pas de chiffres personnels pour ce rôle</p>
                <p className="mt-1 text-sm text-neutral-400">
                  Les indicateurs de performance se calculent à partir d&apos;un code représentant, que ton
                  compte n&apos;a pas.
                </p>
              </>
            ) : (
              <>
                <p className="font-medium text-neutral-500">Compte non relié à l&apos;ERP</p>
                <p className="mt-1 text-sm text-neutral-400">
                  Aucun code représentant n&apos;est associé à ton compte Active Directory — tes chiffres ne
                  peuvent pas être calculés. Rapproche-toi de l&apos;administrateur.
                </p>
              </>
            )}
          </div>
          {graphiques}
        </>
      ) : (
        <>
          {/* KPI du mois */}
          <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <GaugeCard
              icon={Wallet}
              label="CA du mois vs objectif"
              realiseLabel={formatEUR(perf.kpis.ca)}
              cibleLabel={perf.objectif.cible != null ? formatEUR(perf.objectif.cible) : undefined}
              pct={perf.objectif.tauxPct}
            />
            <StatTile
              icon={ShoppingCart}
              label="Commandes"
              value={String(perf.kpis.commandes)}
              hint={perf.kpis.commandes > 0 ? `Panier moyen ${formatEUR(perf.kpis.panierMoyen)}` : 'Aucune commande ce mois'}
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
              hint={`${perf.couverture.sansCommande} client${perf.couverture.sansCommande > 1 ? 's' : ''} sans commande ce mois`}
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
                      <span className="text-emerald-700">+{perf.kpis.deltaPct}%</span> vs{' '}
                      {MOIS_LABELS[perf.periode.mois - 1].toLowerCase()} {perf.periode.annee - 1}
                    </p>
                    <p className="text-xs text-neutral-400">{formatEUR(perf.kpis.caN1)} l&apos;an dernier</p>
                  </div>
                </>
              ) : (
                <>
                  <TrendingDown size={22} className="text-red-500" />
                  <div>
                    <p className="text-sm font-medium">
                      <span className="text-red-700">{perf.kpis.deltaPct}%</span> vs{' '}
                      {MOIS_LABELS[perf.periode.mois - 1].toLowerCase()} {perf.periode.annee - 1}
                    </p>
                    <p className="text-xs text-neutral-400">{formatEUR(perf.kpis.caN1)} l&apos;an dernier</p>
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
                  Classement par CA facturé (code {perf.idRepr})
                  {/* Le détail du classement n'existe que dans l'espace Direction : renvoi réservé à l'encadrement. */}
                  {estEncadrement(me.role) ? ' — détail complet dans Direction commerciale.' : '.'}
                </p>
              </div>
            </div>
          </section>

          {/* Évolution du CA et des commandes (6 mois) + répartition des visites */}
          {graphiques}

          <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
            {/* Top magasins */}
            <section className={card}>
              <h2 className={cardHeader}>
                <Store size={17} className="text-brand dark:text-accent" />
                Top de mes clients — {MOIS_LABELS[perf.periode.mois - 1]}
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
                      <Link href={`/clients/${encodeURIComponent(m.id)}`} className={LIEN_CLIENT}>
                        {m.enseigne}
                      </Link>
                      <span className="shrink-0 text-xs text-neutral-400">
                        {m.nb} cmd{m.nb > 1 ? 's' : ''}
                      </span>
                      <span className="shrink-0 text-sm font-semibold text-brand dark:text-accent">{formatEUR(m.ca)}</span>
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
                <span className="ml-auto rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-800">
                  {perf.couverture.sansCommande}
                </span>
              </h2>
              {perf.couverture.exemplesSansCommande.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">
                  🎉 Tous les clients du portefeuille ont commandé ce mois.
                </p>
              ) : (
                <>
                  <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                    {perf.couverture.exemplesSansCommande.map((c) => (
                      <li key={c.id} className="flex items-center gap-3 px-5 py-3">
                        <Link href={`/clients/${encodeURIComponent(c.id)}`} className={LIEN_CLIENT}>
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

      {suivi ? (
        <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
          {/* Magasins ayant commandé ce mois, par promoteur */}
          <section className="rounded-2xl bg-white shadow-card">
            <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3.5 text-sm font-semibold dark:border-navy-700">
              <UsersRound size={16} className="text-brand dark:text-accent" />
              Clients ayant commandé ce mois — par promoteur
            </h2>
            <CommandesParPromoteur groupes={suivi.commandesParPromoteur ?? []} />
          </section>

          {/* Commandes à suivre / relancer */}
          <section className="rounded-2xl bg-white shadow-card">
            <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3.5 text-sm font-semibold dark:border-navy-700">
              <PackageSearch size={16} className="text-brand dark:text-accent" />
              Commandes à suivre
              <span className="ml-auto text-xs font-normal text-neutral-400">{aSuivre.length}</span>
            </h2>
            {aSuivre.length === 0 ? (
              <p className="px-5 py-6 text-sm text-neutral-400">Aucune commande en attente de livraison.</p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {aSuivre.map((c) => (
                  <li key={c.id}>
                    <Link
                      href={`/commandes/${encodeURIComponent(c.id)}`}
                      className={`flex items-center gap-3 px-5 py-2.5 transition hover:bg-neutral-50 focus-visible:-outline-offset-2 dark:hover:bg-navy-800/50 ${FOCUS}`}
                    >
                      <span className={`h-2 w-2 shrink-0 rounded-full ${c.enRetard ? 'bg-red-400' : 'bg-amber-400'}`} aria-hidden />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">{c.magasin}</p>
                        <p className="text-xs text-neutral-400">
                          {c.numero}
                          {c.dateCommande ? ` · ${new Date(c.dateCommande).toLocaleDateString('fr-FR')}` : ''}
                        </p>
                      </div>
                      <span className={`shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                        c.enRetard
                          ? 'bg-red-500/12 text-red-700'
                          : c.statut === 'EN_PREPARATION'
                            ? 'bg-amber-500/12 text-amber-800'
                            : 'bg-brand/12 text-brand dark:text-accent'
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
