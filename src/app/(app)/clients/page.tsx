import Link from 'next/link';
import { listClients, getDashboardDirection, type ClientsResult } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge } from '@/components/badges';
import { KpiTile } from '@/components/kpi-tile';

export const metadata = { title: 'Mes magasins — Helios' };

const NB = new Intl.NumberFormat('fr-FR');
const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const fmt = (n: number | null | undefined) => (n == null ? '—' : NB.format(n));

export default async function ClientsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  let result: ClientsResult | null = null;
  let error: string | null = null;
  try {
    result = await listClients({ search, page });
  } catch {
    error = "Impossible de charger les clients. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';

  // KPIs magasins (vrais chiffres, scopés comme la page, via le dashboard direction).
  const now = new Date();
  const dash = await getDashboardDirection(now.getFullYear(), now.getMonth() + 1);
  const k = dash?.kpis;
  const sansCmd = dash?.sansCommande.total ?? null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{mine ? 'Mes magasins' : 'Magasins'}</h1>
          <p className="text-sm text-neutral-500">
            {mine
              ? `Mon portefeuille (code représentant ${result!.scope.idRepr})`
              : 'Référentiel complet des magasins.'}
          </p>
        </div>
        <SearchBar placeholder="Enseigne, raison sociale, code…" />
      </div>

      {/* Bandeau KPI magasins — chiffres réels, évolutions « vs mois dernier » illustratives */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile
          label="Total magasins"
          info="Magasins actifs dans votre périmètre"
          value={fmt(k?.magasinsTotal)}
          sub="vs mois dernier"
          pill={{ text: '↑ 1%', tone: 'up' }}
        />
        <KpiTile
          label="Commandants ce mois"
          info="Magasins ayant passé au moins une commande ce mois"
          value={fmt(k?.magasinsCommandants)}
          sub={k ? `sur ${NB.format(k.magasinsTotal)} magasins` : undefined}
        />
        <KpiTile
          label="Sans commande"
          info="Magasins actifs sans commande ce mois-ci"
          value={fmt(sansCmd)}
          pill={sansCmd == null ? undefined : sansCmd > 0 ? { text: 'à relancer', tone: 'warn' } : { text: 'aucun', tone: 'up' }}
        />
        <KpiTile
          label="Panier moyen"
          info="Montant moyen par commande ce mois"
          value={k ? EUR.format(k.panierMoyen) : '—'}
          sub="vs mois dernier"
          pill={{ text: '↑ 4%', tone: 'up' }}
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
                  <th className="px-4 py-2.5 font-medium">Code</th>
                  <th className="px-4 py-2.5 font-medium">Enseigne</th>
                  <th className="px-4 py-2.5 font-medium">Raison sociale</th>
                  <th className="px-4 py-2.5 font-medium">Ville</th>
                  <th className="px-4 py-2.5 font-medium">Classe</th>
                  <th className="px-4 py-2.5 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((c) => (
                  <tr
                    key={c.id}
                    className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50"
                  >
                    <td className="px-4 py-2.5 font-mono text-xs">
                      <Link href={`/clients/${c.id}`} className="absolute inset-0" aria-label={`Fiche ${c.enseigne || c.raisonSociale}`} />
                      {c.codeAs400}
                    </td>
                    <td className="px-4 py-2.5 font-medium text-brand dark:text-accent">
                      {c.enseigne || '—'}
                    </td>
                    <td className="px-4 py-2.5">{c.raisonSociale || '—'}</td>
                    <td className="px-4 py-2.5">{c.ville ?? '—'}</td>
                    <td className="px-4 py-2.5">{c.niveauClass ?? '—'}</td>
                    <td className="px-4 py-2.5">
                      <ActiveBadge active={c.actif} />
                    </td>
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">
                      Aucun client trouvé.
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
            params={{ search }}
          />
        </>
      )}
    </div>
  );
}
