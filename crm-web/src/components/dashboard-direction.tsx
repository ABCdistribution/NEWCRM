import { Suspense } from 'react';
import Link from 'next/link';
import {
  Wallet,
  ShoppingCart,
  Store,
  Target,
  Trophy,
  Landmark,
  ChevronLeft,
  ChevronRight,
  TrendingUp,
  TrendingDown,
  PackageX,
  Minus,
} from 'lucide-react';
import { getDashboardDirection, type Me } from '@/lib/api';
import { aujourdhuiParis } from '@/lib/planning-dates';
import { StatTile } from '@/components/stat-tile';
import { ProspectionCaChart } from '@/components/prospection-ca-chart';
import { CaFamilleDonut } from '@/components/ca-famille-donut';
import { ScatterObjectif } from '@/components/scatter-objectif';
import { DonutChart, COULEURS_DONUT } from '@/components/donut-chart';
import { ClassBadge } from '@/components/class-badge';
import { DashboardCS } from '@/components/dashboard-cs';
import { CarteAccueil, CarteAccueilSquelette } from '@/components/carte-accueil';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const MOIS_LABELS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const card =
  'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700';

const FOCUS =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';

function Delta({ pct }: { pct: number | null }) {
  if (pct == null)
    return (
      <span className="inline-flex items-center gap-1 text-xs text-neutral-400" title="Pas de référence N-1">
        <Minus size={12} aria-hidden /> n/d
      </span>
    );
  const up = pct >= 0;
  return (
    <span
      className={`inline-flex items-center gap-1 text-xs font-semibold ${up ? 'text-emerald-500' : 'text-red-400'}`}
    >
      {up ? <TrendingUp size={13} aria-hidden /> : <TrendingDown size={13} aria-hidden />}
      {up ? '+' : ''}
      {pct}%
    </span>
  );
}

/** CA réalisé / objectif en euros ; la couleur de seuil suit l'atteinte (sans l'afficher en %). */
function RealiseObjectif({ ca, objectif, pct }: { ca: number; objectif: number | null; pct: number | null }) {
  if (objectif == null) {
    return (
      <span>
        <span className="font-semibold dark:text-accent">{EUR.format(ca)}</span>
        <span className="text-xs text-neutral-400"> / —</span>
      </span>
    );
  }
  const tone =
    pct == null ? 'dark:text-accent' : pct >= 100 ? 'text-emerald-500' : pct >= 70 ? 'text-amber-400' : 'text-red-400';
  return (
    <span className="whitespace-nowrap">
      <span className={`font-semibold ${tone}`}>{EUR.format(ca)}</span>
      <span className="text-xs text-neutral-400"> / {EUR.format(objectif)}</span>
    </span>
  );
}

/**
 * La période arrive d'une URL (?annee=&mois=), donc d'une saisie libre : on la ramène à des bornes sûres
 * (année entière entre 2000 et 2100, mois entre 1 et 12), sinon le mois courant. L'API rebornerait le mois
 * mais accepterait n'importe quelle année.
 */
function periodeSure(annee: number, mois: number): { annee: number; mois: number } {
  // Mois courant À PARIS (fuseau de l'API), pas celui du serveur Next.
  const maintenant = aujourdhuiParis();
  return {
    annee: Number.isInteger(annee) && annee >= 2000 && annee <= 2100 ? annee : maintenant.getFullYear(),
    mois: Number.isInteger(mois) && mois >= 1 && mois <= 12 ? mois : maintenant.getMonth() + 1,
  };
}

/**
 * Accueil « direction » (ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR) : composant serveur, repris du
 * tableau de bord de pilotage d'ABC Pilot. Le chef de secteur voit « Mon secteur » (DashboardCS, carte en
 * mode points) ; les autres rôles voient le pilotage de toute la force de vente (carte des équipes).
 * Les chiffres viennent de /dashboard/direction, que l'API filtre par rôle et périmètre : ce composant
 * n'applique aucun filtre. L'appelant (la page d'accueil) vérifie le rôle et fournit `me` déjà chargé.
 *
 * Trou connu côté API (à corriger dans crm-api, rien n'est compensé ici) : /dashboard/direction n'est pas
 * borné par périmètre pour DIRECTEUR_REGIONAL (CA, classement, secteurs, sans-commande : toute la force de
 * vente), et pour CHEF_SECTEUR le bloc prospection et le nuage objectif / CA (scatterMagasins) couvrent le
 * réseau entier.
 *
 * Couleurs : jetons du thème (`brand`, `accent`, `navy-*`) ; vert / ambre / rouge SÉMANTIQUES
 * (atteint, alerte, baisse) ; couleurs JS des graphiques documentées dans `donut-chart.tsx`.
 */
export async function DashboardDirection({
  me,
  annee: anneeDemandee,
  mois: moisDemande,
}: {
  me: Me;
  annee: number;
  mois: number;
}) {
  const { annee, mois } = periodeSure(anneeDemandee, moisDemande);

  const prev = mois === 1 ? { annee: annee - 1, mois: 12 } : { annee, mois: mois - 1 };
  const next = mois === 12 ? { annee: annee + 1, mois: 1 } : { annee, mois: mois + 1 };

  const data = await getDashboardDirection(annee, mois);
  const prenom = me.displayName.split(/\s+/)[0] ?? '';
  const isCS = me.role === 'CHEF_SECTEUR';
  const carteMode: 'equipes' | 'secteur' | null = isCS
    ? 'secteur'
    : me.role === 'ADMIN' || me.role === 'DIRECTION' || me.role === 'DIRECTEUR_REGIONAL'
      ? 'equipes'
      : null;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{isCS ? 'Mon secteur' : 'Pilotage force de vente'}</h1>
          <p className="text-sm text-neutral-500">
            Bonjour {prenom} — {data?.scope.label.toLowerCase() ?? 'vue globale'}.
          </p>
        </div>

        {/* Sélecteur de mois */}
        <nav aria-label="Choix du mois" className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
          <Link
            href={`/?annee=${prev.annee}&mois=${prev.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label={`Mois précédent : ${MOIS_LABELS[prev.mois - 1]} ${prev.annee}`}
          >
            <ChevronLeft size={16} aria-hidden />
          </Link>
          <span className="min-w-36 text-center text-sm font-medium">
            {MOIS_LABELS[mois - 1]} {annee}
          </span>
          <Link
            href={`/?annee=${next.annee}&mois=${next.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label={`Mois suivant : ${MOIS_LABELS[next.mois - 1]} ${next.annee}`}
          >
            <ChevronRight size={16} aria-hidden />
          </Link>
        </nav>
      </div>

      {/* Carte en haut de l'accueil ; ne bloque pas le reste de la page (Suspense + erreurs localisées). */}
      {carteMode ? (
        <Suspense fallback={<CarteAccueilSquelette />}>
          <CarteAccueil mode={carteMode} role={me.role} />
        </Suspense>
      ) : null}

      {!data ? (
        <p
          className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
          role="alert"
        >
          Chiffres indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : isCS ? (
        <DashboardCS data={data} />
      ) : (
        <>
          {/* KPIs consolidés du mois */}
          <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatTile
              icon={Wallet}
              label="CA du mois"
              value={EUR.format(data.kpis.ca)}
              hint={
                data.kpis.deltaPct != null
                  ? `${data.kpis.deltaPct >= 0 ? '+' : ''}${data.kpis.deltaPct}% vs ${annee - 1} (${EUR.format(data.kpis.caN1)})`
                  : `Pas de référence ${annee - 1}`
              }
            />
            <StatTile
              icon={ShoppingCart}
              label="Commandes"
              value={String(data.kpis.commandes)}
              hint={
                data.kpis.commandes > 0
                  ? `Panier moyen ${EUR.format(data.kpis.panierMoyen)}`
                  : 'Aucune commande ce mois'
              }
            />
            <StatTile
              icon={Store}
              label="Clients commandants"
              value={`${data.kpis.magasinsCommandants}/${data.kpis.magasinsTotal}`}
              hint={`${data.sansCommande.total} client${data.sansCommande.total > 1 ? 's' : ''} sans commande`}
            />
            <StatTile
              icon={Target}
              label="Objectifs atteints"
              value={`${data.objectifs.atteints}/${data.objectifs.definis}`}
              hint={
                data.objectifs.sansObjectif > 0
                  ? `${data.objectifs.sansObjectif} promoteur${data.objectifs.sansObjectif > 1 ? 's' : ''} sans objectif`
                  : 'Tous les promoteurs ont un objectif'
              }
            />
          </section>

          {/* CA réalisé vs objectif côté prospection, et répartition du CA par famille */}
          <div className="grid grid-cols-1 gap-5 xl:grid-cols-5">
            <div className="xl:col-span-3">
              <ProspectionCaChart p={data.prospection} moisLabel={`${MOIS_LABELS[mois - 1]} ${annee}`} />
            </div>
            <div className="xl:col-span-2">
              <CaFamilleDonut data={data.caParFamille} moisLabel={`${MOIS_LABELS[mois - 1]} ${annee}`} />
            </div>
          </div>

          {/* Nuage objectif vs réalisé : sous la diagonale = à relancer */}
          <section className={card}>
            <h2 className={cardHeader}>
              <Target size={17} className="text-brand dark:text-accent" aria-hidden />
              Objectif vs CA réalisé — par client
            </h2>
            <ScatterObjectif points={data.scatterMagasins} />
          </section>

          {/* Graphes KPI : couverture magasins + objectifs */}
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
            <section className={card}>
              <h2 className={cardHeader}>
                <Store size={17} className="text-brand dark:text-accent" aria-hidden />
                Couverture du mois
              </h2>
              <DonutChart
                segments={[
                  { label: 'Ont commandé', value: data.kpis.magasinsCommandants, color: COULEURS_DONUT.ok },
                  { label: 'Sans commande', value: Math.max(0, data.kpis.magasinsTotal - data.kpis.magasinsCommandants), color: COULEURS_DONUT.alerte },
                ]}
                centerValue={
                  data.kpis.magasinsTotal > 0
                    ? `${Math.round((data.kpis.magasinsCommandants / data.kpis.magasinsTotal) * 100)}%`
                    : '—'
                }
                centerLabel="couverture"
              />
            </section>
            <section className={card}>
              <h2 className={cardHeader}>
                <Target size={17} className="text-brand dark:text-accent" aria-hidden />
                Objectifs du mois
              </h2>
              <DonutChart
                segments={[
                  { label: 'Atteints', value: data.objectifs.atteints, color: COULEURS_DONUT.ok },
                  { label: 'Manqués', value: data.objectifs.manques, color: COULEURS_DONUT.ko },
                  { label: 'Sans objectif', value: data.objectifs.sansObjectif, color: COULEURS_DONUT.neutre },
                ]}
                centerValue={`${data.objectifs.atteints}/${data.objectifs.definis}`}
                centerLabel="atteints"
              />
            </section>
          </div>

          <div className="grid grid-cols-1 gap-5 xl:grid-cols-5">
            {/* Classement des promoteurs — en xl, le contenu est calé en absolu pour remplir
                exactement la hauteur de la colonne de droite (pas de vide en bas de carte). */}
            <section className={`${card} relative overflow-hidden xl:col-span-3 xl:min-h-[30rem]`}>
              <div className="flex max-h-[30rem] flex-col xl:absolute xl:inset-0 xl:max-h-none">
                <h2 className={`${cardHeader} shrink-0`}>
                  <Trophy size={17} className="text-brand dark:text-accent" aria-hidden />
                  Classement des promoteurs — {MOIS_LABELS[mois - 1]}
                </h2>
                {data.classement.length === 0 ? (
                  <p className="px-5 py-4 text-sm text-neutral-400">Aucun promoteur relié à l&apos;ERP.</p>
                ) : (
                  <div className="min-h-0 flex-1 overflow-auto">
                    <table className="w-full text-sm">
                      <thead className="sticky top-0 z-10 bg-white text-left text-xs text-neutral-400 dark:bg-navy-950">
                        <tr>
                          <th scope="col" className="px-5 py-2 font-medium">#</th>
                          <th scope="col" className="px-2 py-2 font-medium">Promoteur</th>
                          <th scope="col" className="px-2 py-2 font-medium">Secteur</th>
                          <th scope="col" className="px-2 py-2 text-right font-medium">CA / objectif</th>
                          <th scope="col" className="px-5 py-2 text-right font-medium">vs N-1</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                        {data.classement.map((p, i) => (
                          <tr key={`${p.idRepr}-${p.userId ?? 'x'}`} className={p.isActive ? '' : 'opacity-50'}>
                            <td className="px-5 py-2.5">
                              <span className="flex h-6 w-6 items-center justify-center rounded-full bg-neutral-100 text-xs font-semibold text-neutral-500 dark:bg-navy-800 dark:text-white">
                                {i + 1}
                              </span>
                            </td>
                            <td className="px-2 py-2.5">
                              <p className="font-medium">{p.nom}</p>
                              <p className="font-mono text-[11px] text-neutral-400">code {p.idRepr}</p>
                            </td>
                            <td className="px-2 py-2.5">
                              {p.secteur ? (
                                <span className="rounded-md bg-neutral-100 px-1.5 py-0.5 text-xs font-medium dark:bg-navy-800">
                                  {p.secteur.code}
                                </span>
                              ) : (
                                <span className="text-xs text-neutral-400">—</span>
                              )}
                            </td>
                            <td className="px-2 py-2.5 text-right">
                              <RealiseObjectif ca={p.ca} objectif={p.objectif} pct={p.tauxPct} />
                            </td>
                            <td className="px-5 py-2.5 text-right">
                              <Delta pct={p.deltaPct} />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </section>

            <div className="flex flex-col gap-5 xl:col-span-2">
              {/* CA par secteur */}
              <section className={card}>
                <h2 className={cardHeader}>
                  <Landmark size={17} className="text-brand dark:text-accent" aria-hidden />
                  CA par secteur
                </h2>
                {data.caParSecteur.length === 0 ? (
                  <p className="px-5 py-4 text-sm text-neutral-400">
                    Aucun secteur défini pour le moment.
                  </p>
                ) : (
                  <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                    {data.caParSecteur.map((s) => (
                      <li key={s.id ?? 'hors'} className="flex items-center gap-3 px-5 py-3">
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium">
                            {s.nom}
                            <span className="ml-1.5 font-mono text-[11px] text-neutral-400">{s.code}</span>
                          </p>
                          <p className="truncate text-xs text-neutral-400">
                            {s.chef ? `Chef : ${s.chef} · ` : ''}
                            {s.promoteurs} promoteur{s.promoteurs > 1 ? 's' : ''}
                          </p>
                        </div>
                        <div className="shrink-0 text-right">
                          <p className="text-sm font-semibold dark:text-accent">{EUR.format(s.ca)}</p>
                          <Delta pct={s.deltaPct} />
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </section>

              {/* Magasins sans commande */}
              <section className={card}>
                <h2 className={cardHeader}>
                  <PackageX size={17} className="text-amber-400" aria-hidden />
                  Sans commande ce mois
                  <span className="ml-auto rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-500">
                    {data.sansCommande.total}
                  </span>
                </h2>
                {data.sansCommande.exemples.length === 0 ? (
                  <p className="px-5 py-4 text-sm text-neutral-400">
                    🎉 Tous les clients actifs ont commandé ce mois.
                  </p>
                ) : (
                  <>
                    <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                      {data.sansCommande.exemples.map((c) => (
                        <li key={c.id} className="flex items-center gap-3 px-5 py-2.5">
                          <Link
                            href={`/clients/${encodeURIComponent(c.id)}`}
                            className={`min-w-0 flex-1 truncate rounded-md text-sm font-medium text-brand hover:underline dark:text-accent ${FOCUS}`}
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
                    {data.sansCommande.total > data.sansCommande.exemples.length ? (
                      <p className="border-t border-neutral-100 px-5 py-2.5 text-xs text-neutral-400 dark:border-navy-700">
                        … et {data.sansCommande.total - data.sansCommande.exemples.length} autres —{' '}
                        <Link href="/clients?vue=portefeuille" className={`rounded-sm underline ${FOCUS}`}>tous les clients</Link>.
                      </p>
                    ) : null}
                  </>
                )}
              </section>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
