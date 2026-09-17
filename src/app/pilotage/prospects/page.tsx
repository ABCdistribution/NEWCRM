import Link from 'next/link';
import {
  getMe,
  listProspects,
  getProspectPipeline,
  listSecteurs,
  type ProspectsResult,
  type ProspectRow,
  type ProspectStatut,
} from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { KpiTile } from '@/components/kpi-tile';
import { StatutBadge, STATUT_LABELS, STATUT_ACCENT, SOURCE_LABELS } from '@/components/prospect-badges';
import { ProspectPipeline } from '@/components/prospect-pipeline';
import { ProspectCreate } from '@/components/prospect-create';

export const metadata = { title: 'Prospection — Helios' };

const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];
const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const NB = new Intl.NumberFormat('fr-FR');
const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
const fmt = (n: number | null) => (n == null ? '—' : NB.format(n));

export default async function ProspectsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  const [pipeline, secteursBruts] = await Promise.all([getProspectPipeline(), listSecteurs()]);
  const secteurs = (secteursBruts ?? []).map((s) => ({ id: s.id, code: s.code, nom: s.nom }));

  let liste: ProspectsResult | null = null;
  let error: string | null = null;
  try {
    liste = await listProspects({ search, page });
  } catch {
    error = "Impossible de charger les prospects. L'API est-elle démarrée ?";
  }

  // --- Indicateurs business dérivés du pipeline complet --------------------
  const ETAPES_ACTIVES: ProspectStatut[] = ['NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION'];
  const colonnes = pipeline ?? [];
  const colonnesActives = colonnes.filter((c) => ETAPES_ACTIVES.includes(c.statut));
  const actifs: ProspectRow[] = colonnesActives.flatMap((c) => c.prospects);
  const pipelinePondere = colonnesActives.reduce((somme, c) => somme + (c.valeurPonderee ?? 0), 0);
  const gagnes = colonnes.find((c) => c.statut === 'GAGNE')?.total ?? 0;
  const perdus = colonnes.find((c) => c.statut === 'PERDU')?.total ?? 0;
  const transformation = gagnes + perdus > 0 ? Math.round((gagnes / (gagnes + perdus)) * 100) : null;

  // À relancer : actifs sans activité depuis 14 jours, les plus anciens d'abord.
  const DORMANT_JOURS = 14;
  const maintenant = Date.now();
  const joursDepuis = (iso: string | null) =>
    iso ? Math.floor((maintenant - new Date(iso).getTime()) / 86_400_000) : null;
  const aRelancer = actifs
    .map((p) => ({ ...p, inactifDepuis: joursDepuis(p.lastActivityAt ?? p.createdAt) ?? 0 }))
    .filter((p) => p.inactifDepuis >= DORMANT_JOURS)
    .sort((a, b) => b.inactifDepuis - a.inactifDepuis);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Prospection</h1>
        </div>
        <div className="flex items-center gap-2">
          <SearchBar placeholder="Enseigne, raison sociale…" />
          <ProspectCreate secteurs={secteurs} />
        </div>
      </div>

      {/* KPI business */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile label="Pipeline pondéré" value={EUR.format(pipelinePondere)} />
        <KpiTile label="Prospects actifs" value={fmt(actifs.length)} />
        <KpiTile
          label="À relancer"
          value={fmt(aRelancer.length)}
          pill={aRelancer.length > 0 ? { text: `≥ ${DORMANT_JOURS} j`, tone: 'down' } : undefined}
        />
        <KpiTile label="Transformation" value={transformation != null ? `${transformation} %` : '—'} />
      </section>

      <section className="rounded-2xl bg-white shadow-card">
          <h2 className="flex items-center gap-2 border-b border-neutral-100 px-4 py-3 text-sm font-semibold dark:border-navy-700">
            À relancer
            {aRelancer.length > 0 ? (
              <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-semibold text-red-500">
                {aRelancer.length}
              </span>
            ) : null}
          </h2>
          {aRelancer.length === 0 ? (
            <p className="px-4 py-6 text-sm text-neutral-400">Tout le pipeline a été touché depuis {DORMANT_JOURS} jours. 👍</p>
          ) : (
            <ul className="max-h-64 divide-y divide-neutral-100 overflow-y-auto dark:divide-navy-700">
              {aRelancer.slice(0, 12).map((p) => (
                <li key={p.id} className="relative px-4 py-2.5 hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                  <Link href={`/pilotage/prospects/${p.id}`} className="absolute inset-0" aria-label={`Fiche ${p.enseigne}`} />
                  <div className="flex items-center gap-2">
                    <span className="min-w-0 flex-1 truncate text-sm font-medium">{p.enseigne}</span>
                    <span className="shrink-0 text-xs font-semibold text-red-500">{p.inactifDepuis} j</span>
                  </div>
                  <div className="mt-0.5 flex items-center gap-2 text-[11px] text-neutral-400">
                    <StatutBadge value={p.statut} />
                    {p.assignedTo ? <span className="truncate">{p.assignedTo.displayName}</span> : null}
                  </div>
                </li>
              ))}
            </ul>
          )}
      </section>

      {/* Kanban drag & drop */}
      {colonnes.length > 0 ? <ProspectPipeline colonnes={colonnes} /> : null}

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</p>
      ) : (
        <ListeView data={liste} search={search} />
      )}
    </div>
  );
}

function ListeView({ data, search }: { data: ProspectsResult | null; search: string }) {
  if (!data) {
    return (
      <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Prospects indisponibles — l&apos;API est-elle démarrée ?
      </p>
    );
  }
  const offset = (data.page - 1) * data.limit;
  return (
    <>
      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">#</th>
              <th className="px-4 py-2.5 font-medium">Prospect</th>
              <th className="px-4 py-2.5 font-medium">Société</th>
              <th className="px-4 py-2.5 font-medium">Source</th>
              <th className="px-4 py-2.5 font-medium">Responsable</th>
              <th className="px-4 py-2.5 text-right font-medium">Potentiel/an</th>
              <th className="px-4 py-2.5 font-medium">Étape</th>
              <th className="px-4 py-2.5 font-medium">Créé le</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {data.data.map((p, i) => (
              <tr key={p.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-3 text-neutral-400 tabular-nums">{offset + i + 1}</td>
                <td className="px-4 py-3">
                  <Link href={`/pilotage/prospects/${p.id}`} className="absolute inset-0" aria-label={`Fiche ${p.enseigne}`} />
                  <p className="font-medium text-brand dark:text-accent">{p.enseigne}</p>
                  {p.ville ? <p className="text-xs text-neutral-400">{p.ville}</p> : null}
                </td>
                <td className="px-4 py-3 text-neutral-500">{p.raisonSociale}</td>
                <td className="px-4 py-3 text-neutral-500">{p.source ? SOURCE_LABELS[p.source] ?? p.source : '—'}</td>
                <td className="px-4 py-3">
                  {p.assignedTo ? (
                    p.assignedTo.displayName
                  ) : (
                    <span className="text-xs text-neutral-400">Non assigné</span>
                  )}
                </td>
                <td className="px-4 py-3 text-right font-medium tabular-nums">
                  {p.potentielCaAnnuel != null ? EUR.format(p.potentielCaAnnuel) : '—'}
                </td>
                <td className="px-4 py-3">
                  <StatutBadge value={p.statut} />
                </td>
                <td className="px-4 py-3 text-neutral-500">
                  {p.createdAt ? DT.format(new Date(p.createdAt)) : '—'}
                </td>
              </tr>
            ))}
            {data.data.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-neutral-400">
                  Aucun prospect{search ? ' pour cette recherche' : ''}.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
      <Pagination total={data.total} page={data.page} limit={data.limit} params={{ search }} />
    </>
  );
}
