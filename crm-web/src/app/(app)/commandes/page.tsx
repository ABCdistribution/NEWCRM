import Link from 'next/link';
import { getStatsCommandes, listCommandes, type CommandesResult, type StatutLivraison } from '@/lib/api';
import { ENCADREMENT, TOUS_ROLES, requireRole } from '@/lib/roles';
import { KpiTile } from '@/components/kpi-tile';
import { LivraisonBadge, LIVRAISON } from '@/components/livraison-badge';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { OrigineBadge, OrigineFilter, parseOrigine, type Origine } from '@/components/origine-commande';

export const metadata = { title: 'Commandes' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
const EUR0 = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const NB = new Intl.NumberFormat('fr-FR');

/** Filtres de livraison proposés : « En préparation » et « Livrée partielle » n'en sont pas (leurs pastilles restent affichées sur les commandes). */
const FILTRES_LIVRAISON: readonly StatutLivraison[] = ['EXPEDIEE', 'LIVREE'];
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
  searchParams: Promise<{ search?: string; page?: string; annulees?: string; livraison?: string; origine?: string; stats?: string }>;
}) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const annulees = sp.annulees === 'true';
  const livraison = FILTRES_LIVRAISON.includes(sp.livraison as StatutLivraison)
    ? (sp.livraison as StatutLivraison)
    : undefined;
  const origine = parseOrigine(sp.origine);
  // Indicateurs : la journée par défaut, le mois sur demande (?stats=mois).
  const periodeStats: 'jour' | 'mois' = sp.stats === 'mois' ? 'mois' : 'jour';

  /** URL de la page avec un ou plusieurs filtres modifiés ; tous les autres sont conservés. */
  const lien = (modif: {
    annulees?: boolean;
    livraison?: StatutLivraison | null;
    origine?: Origine | null;
    stats?: 'jour' | 'mois';
  }) => {
    const f = {
      annulees: modif.annulees ?? annulees,
      livraison: modif.livraison === undefined ? livraison : (modif.livraison ?? undefined),
      origine: modif.origine === undefined ? origine : (modif.origine ?? undefined),
      stats: modif.stats ?? periodeStats,
    };
    const q = new URLSearchParams();
    if (search) q.set('search', search);
    if (f.annulees) q.set('annulees', 'true');
    if (f.livraison) q.set('livraison', f.livraison);
    if (f.origine) q.set('origine', f.origine);
    if (f.stats === 'mois') q.set('stats', 'mois');
    const str = q.toString();
    return str ? `/commandes?${str}` : '/commandes';
  };
  const avecLivraison = (statut?: StatutLivraison) => lien({ livraison: statut ?? null });
  const avecOrigine = (o?: Origine) => lien({ origine: o ?? null });

  let result: CommandesResult | null = null;
  let error: string | null = null;
  try {
    result = await listCommandes({ search, page, annulees, livraison, origine });
  } catch {
    error = "Impossible de charger les commandes. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';

  // Bandeau d'indicateurs : encadrement uniquement (l'API réserve ces chiffres à ces rôles), du jour par défaut.
  const avecKpi = ENCADREMENT.includes(acces.me.role);
  const k = avecKpi ? await getStatsCommandes(periodeStats) : null;
  const quand = periodeStats === 'jour' ? 'du jour' : 'du mois';
  const ceMoment = periodeStats === 'jour' ? "aujourd'hui" : 'ce mois';

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
            href={lien({ annulees: !annulees })}
            className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${
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

      {avecKpi ? (
        <section aria-label={`Indicateurs ${quand}`} className="flex flex-col gap-3">
          {/* Période des indicateurs : la journée à l'ouverture, le mois sur demande (?stats=mois) */}
          <nav aria-label="Période des indicateurs" className="flex items-center gap-1 self-start rounded-xl bg-white p-1 shadow-card">
            {(['jour', 'mois'] as const).map((p) => (
              <Link
                key={p}
                href={lien({ stats: p })}
                aria-current={periodeStats === p ? 'true' : undefined}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${
                  periodeStats === p ? 'bg-brand text-white' : 'text-neutral-500 hover:bg-neutral-100 dark:hover:bg-navy-800'
                }`}
              >
                {p === 'jour' ? "Aujourd'hui" : 'Ce mois'}
              </Link>
            ))}
          </nav>
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <KpiTile
              label={`CA ${quand}`}
              info={`Chiffre d'affaires des commandes ${quand}`}
              value={k ? EUR0.format(k.ca) : '—'}
              sub={periodeStats === 'jour' ? 'vs même jour N-1' : 'vs N-1'}
              pill={
                k?.deltaPct == null
                  ? undefined
                  : { text: `${k.deltaPct >= 0 ? '↑' : '↓'} ${Math.abs(k.deltaPct)}%`, tone: k.deltaPct >= 0 ? 'up' : 'down' }
              }
            />
            <KpiTile
              label={`Commandes ${quand}`}
              info={`Nombre de commandes ${ceMoment}`}
              value={k ? NB.format(k.commandes) : '—'}
              sub={ceMoment}
            />
            <KpiTile
              label="Panier moyen"
              info={`Montant moyen par commande ${ceMoment}`}
              value={k ? EUR0.format(k.panierMoyen) : '—'}
              sub={ceMoment}
            />
            <KpiTile
              label="Clients commandants"
              info={`Clients ayant passé commande ${ceMoment}`}
              value={k ? NB.format(k.clientsCommandants) : '—'}
              sub={k ? `sur ${NB.format(k.clientsTotal)} clients` : undefined}
            />
          </div>
        </section>
      ) : null}

      {/* Filtre par statut de livraison (côté API : GET /commandes?livraison=). */}
      <div className="flex flex-wrap items-center gap-1.5 rounded-2xl bg-white p-3 shadow-card">
        <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Livraison</span>
        <Link
          href={avecLivraison()}
          className={`rounded-full border px-3 py-1 text-xs font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${
            livraison === undefined
              ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
              : 'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800'
          }`}
        >
          Toutes
        </Link>
        {FILTRES_LIVRAISON.map((statut) => (
          <Link
            key={statut}
            href={avecLivraison(statut)}
            className={`rounded-full border px-3 py-1 text-xs font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${
              livraison === statut
                ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
                : 'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800'
            }`}
          >
            {LIVRAISON[statut].label}
          </Link>
        ))}
        <span className="mx-2 hidden h-4 w-px bg-neutral-200 dark:bg-navy-700 sm:inline-block" aria-hidden="true" />
        {/* Filtre par origine (côté API : GET /commandes?origine=edi|appli). */}
        <OrigineFilter actuelle={origine} href={avecOrigine} />
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
                <Link href={`/commandes/${c.id}`} className="absolute inset-0 focus-visible:outline-2 focus-visible:outline-brand dark:focus-visible:outline-accent" aria-label={`Commande ${c.numero}`} />
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
                    <OrigineBadge commande={c} />
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
                  <th className="px-4 py-2.5 font-medium">Origine</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((c) => (
                  <tr key={c.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-2.5 font-mono text-xs font-medium text-brand dark:text-accent">
                      <Link href={`/commandes/${c.id}`} className="absolute inset-0 focus-visible:outline-2 focus-visible:outline-brand dark:focus-visible:outline-accent" aria-label={`Commande ${c.numero}`} />
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
                    <td className="px-4 py-2.5">
                      <OrigineBadge commande={c} />
                    </td>
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="px-4 py-8 text-center text-neutral-400">
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
            params={{ search, ...(annulees ? { annulees: 'true' } : {}), ...(livraison ? { livraison } : {}), ...(origine ? { origine } : {}), ...(periodeStats === 'mois' ? { stats: 'mois' } : {}) }}
          />
        </>
      )}
    </div>
  );
}
