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
import { getMe, getDashboardDirection } from '@/lib/api';
import { StatTile } from '@/components/stat-tile';
import { CaChart } from '@/components/ca-chart';
import { ClassBadge } from '@/components/class-badge';

export const metadata = { title: 'Pilotage — Helios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const MOIS_LABELS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const card =
  'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700';

function Delta({ pct }: { pct: number | null }) {
  if (pct == null)
    return (
      <span className="inline-flex items-center gap-1 text-xs text-neutral-400" title="Pas de référence N-1">
        <Minus size={12} /> n/d
      </span>
    );
  const up = pct >= 0;
  return (
    <span
      className={`inline-flex items-center gap-1 text-xs font-semibold ${up ? 'text-emerald-500' : 'text-red-400'}`}
    >
      {up ? <TrendingUp size={13} /> : <TrendingDown size={13} />}
      {up ? '+' : ''}
      {pct}%
    </span>
  );
}

function TauxObjectif({ pct }: { pct: number | null }) {
  if (pct == null) return <span className="text-xs text-neutral-400">—</span>;
  const tone = pct >= 100 ? 'text-emerald-500' : pct >= 70 ? 'text-amber-400' : 'text-red-400';
  return <span className={`text-xs font-semibold ${tone}`}>{pct}%</span>;
}

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

  const [me, data] = await Promise.all([getMe(), getDashboardDirection(annee, mois)]);
  const prenom = me?.displayName?.split(/\s+/)[0] ?? '';

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Pilotage force de vente</h1>
          <p className="text-sm text-neutral-500">
            Bonjour {prenom} — {data?.scope.label.toLowerCase() ?? 'vue globale'}.
          </p>
        </div>

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

      {!data ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Chiffres indisponibles — l&apos;API est-elle démarrée ?
        </p>
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
              label="Magasins commandants"
              value={`${data.kpis.magasinsCommandants}/${data.kpis.magasinsTotal}`}
              hint={`${data.sansCommande.total} magasin${data.sansCommande.total > 1 ? 's' : ''} sans commande`}
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

          {/* Courbe CA consolidé 12 mois */}
          <section className={card}>
            <h2 className={cardHeader}>
              <Wallet size={17} className="text-brand" />
              CA mensuel consolidé — {data.ca12mois.anneeN - 1} vs {data.ca12mois.anneeN}
            </h2>
            <CaChart anneeN={data.ca12mois.anneeN} courbeN={data.ca12mois.courbeN} courbeN1={data.ca12mois.courbeN1} />
          </section>

          <div className="grid grid-cols-1 gap-5 xl:grid-cols-5">
            {/* Classement des promoteurs — en xl, le contenu est calé en absolu pour remplir
                exactement la hauteur de la colonne de droite (pas de vide en bas de carte). */}
            <section className={`${card} relative overflow-hidden xl:col-span-3 xl:min-h-[30rem]`}>
              <div className="flex max-h-[30rem] flex-col xl:absolute xl:inset-0 xl:max-h-none">
              <h2 className={`${cardHeader} shrink-0`}>
                <Trophy size={17} className="text-brand dark:text-accent" />
                Classement des promoteurs — {MOIS_LABELS[mois - 1]}
              </h2>
              {data.classement.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">Aucun promoteur relié à l&apos;ERP.</p>
              ) : (
                <div className="min-h-0 flex-1 overflow-auto">
                  <table className="w-full text-sm">
                    <thead className="sticky top-0 z-10 bg-white text-left text-xs text-neutral-400 dark:bg-navy-950">
                      <tr>
                        <th className="px-5 py-2 font-medium">#</th>
                        <th className="px-2 py-2 font-medium">Promoteur</th>
                        <th className="px-2 py-2 font-medium">Secteur</th>
                        <th className="px-2 py-2 text-right font-medium">CA</th>
                        <th className="px-2 py-2 text-right font-medium">vs N-1</th>
                        <th className="px-2 py-2 text-right font-medium">Objectif</th>
                        <th className="px-5 py-2 text-right font-medium">Atteinte</th>
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
                          <td className="px-2 py-2.5 text-right font-semibold dark:text-accent">
                            {EUR.format(p.ca)}
                          </td>
                          <td className="px-2 py-2.5 text-right">
                            <Delta pct={p.deltaPct} />
                          </td>
                          <td className="px-2 py-2.5 text-right text-xs text-neutral-400">
                            {p.objectif != null ? EUR.format(p.objectif) : '—'}
                          </td>
                          <td className="px-5 py-2.5 text-right">
                            <TauxObjectif pct={p.tauxPct} />
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
                  <Landmark size={17} className="text-brand" />
                  CA par secteur
                </h2>
                {data.caParSecteur.length === 0 ? (
                  <p className="px-5 py-4 text-sm text-neutral-400">
                    Aucun secteur — crée-les dans <Link href="/secteurs" className="text-brand underline dark:text-accent">Secteurs</Link>.
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
                  <PackageX size={17} className="text-amber-400" />
                  Sans commande ce mois
                  <span className="ml-auto rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-semibold text-amber-500">
                    {data.sansCommande.total}
                  </span>
                </h2>
                {data.sansCommande.exemples.length === 0 ? (
                  <p className="px-5 py-4 text-sm text-neutral-400">
                    🎉 Tous les magasins actifs ont commandé ce mois.
                  </p>
                ) : (
                  <>
                    <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                      {data.sansCommande.exemples.map((c) => (
                        <li key={c.id} className="flex items-center gap-3 px-5 py-2.5">
                          <Link
                            href={`/clients/${c.id}`}
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
                    {data.sansCommande.total > data.sansCommande.exemples.length ? (
                      <p className="border-t border-neutral-100 px-5 py-2.5 text-xs text-neutral-400 dark:border-navy-700">
                        … et {data.sansCommande.total - data.sansCommande.exemples.length} autres —{' '}
                        <Link href="/clients" className="underline">tous les magasins</Link>.
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
