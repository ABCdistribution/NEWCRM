import Link from 'next/link';
import {
  getMe,
  listProspects,
  countProspects,
  listSecteurs,
  type ProspectsResult,
} from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { KpiTile } from '@/components/kpi-tile';
import { StatutBadge, SOURCE_LABELS } from '@/components/prospect-badges';
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

  // KPIs par statut (vrais comptes via le filtre `statut`).
  const [total, nouveaux, qualifies, perdus] = await Promise.all([
    countProspects({}),
    countProspects({ statut: 'NOUVEAU' }),
    countProspects({ statut: 'QUALIFIE' }),
    countProspects({ statut: 'PERDU' }),
  ]);
  const pctQualif = total && qualifies != null && total > 0 ? Math.round((qualifies / total) * 100) : null;

  let liste: ProspectsResult | null = null;
  let error: string | null = null;
  try {
    liste = await listProspects({ search, page });
  } catch {
    error = "Impossible de charger les prospects. L'API est-elle démarrée ?";
  }
  const secteurs = ((await listSecteurs()) ?? []).map((s) => ({ id: s.id, code: s.code, nom: s.nom }));

  const topProspects = liste
    ? [...liste.data].sort((a, b) => (b.potentielCaAnnuel ?? 0) - (a.potentielCaAnnuel ?? 0)).slice(0, 6)
    : [];

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Prospection</h1>
          <p className="text-sm text-neutral-500">
            Points de vente à développer et pipeline commercial du secteur.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <SearchBar placeholder="Enseigne, raison sociale…" />
          <ProspectCreate secteurs={secteurs} />
        </div>
      </div>

      {/* Bandeau KPI par statut */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile label="Total prospects" info="Tous les prospects de votre périmètre" value={fmt(total)} sub="vs mois dernier" pill={{ text: '↑ 7%', tone: 'up' }} />
        <KpiTile label="Nouveaux" info="À l'étape « Nouveau »" value={fmt(nouveaux)} sub="vs mois dernier" pill={{ text: '↑ 12%', tone: 'up' }} />
        <KpiTile label="Qualifiés" info="À l'étape « Qualifié »" value={fmt(qualifies)} sub={pctQualif != null ? `${pctQualif}% du total` : undefined} />
        <KpiTile label="Perdus" info="Prospects perdus" value={fmt(perdus)} pill={perdus == null ? undefined : perdus > 0 ? { text: '↓ 2', tone: 'down' } : { text: 'aucun', tone: 'up' }} />
      </section>

      {/* Top prospects par potentiel */}
      {topProspects.length > 0 ? (
        <section className="overflow-x-auto rounded-xl bg-white shadow-card">
          <div className="border-b border-neutral-100 px-4 py-3 text-sm font-semibold dark:border-navy-700">
            Top prospects par potentiel
          </div>
          <table className="w-full text-sm">
            <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
              <tr>
                <th className="px-4 py-2.5 font-medium">Enseigne</th>
                <th className="px-4 py-2.5 font-medium">Étape</th>
                <th className="px-4 py-2.5 text-right font-medium">Potentiel CA / an</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
              {topProspects.map((p) => (
                <tr key={p.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                  <td className="px-4 py-2.5 font-medium">
                    <Link href={`/pilotage/prospects/${p.id}`} className="absolute inset-0" aria-label={`Fiche ${p.enseigne}`} />
                    {p.enseigne}
                  </td>
                  <td className="px-4 py-2.5">
                    <StatutBadge value={p.statut} />
                  </td>
                  <td className="px-4 py-2.5 text-right font-semibold tabular-nums">
                    {p.potentielCaAnnuel != null ? EUR.format(p.potentielCaAnnuel) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ) : null}

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
