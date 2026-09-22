import { AlertTriangle, CheckCircle2, Footprints, Gauge, ShieldAlert, Users } from 'lucide-react';
import { getMe, listUsers, listMesPlannings, type UserRow, type PlanningItem } from '@/lib/api';
import { StatTile } from '@/components/stat-tile';

export const metadata = { title: 'Pilotage — Selios' };

/** Encadrement : un chef de secteur voit SES promoteurs (scoping API), un DR / la direction plus large. */
const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** yyyy-mm-dd local. */
function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Lundi de la semaine courante. */
function lundi(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  return d;
}

type LignePromoteur = {
  promoteur: UserRow;
  prevues: number;
  faites: number;
  manquees: number; // passées non faites
  alerte: string | null;
};

function statsSemaine(plannings: PlanningItem[]): { prevues: number; faites: number; manquees: number } {
  const aujourdhui = iso(new Date());
  let faites = 0;
  let manquees = 0;
  for (const p of plannings) {
    if (p.fait) faites += 1;
    else if (iso(new Date(p.datePassage)) < aujourdhui) manquees += 1;
  }
  return { prevues: plannings.length, faites, manquees };
}

export default async function PilotagePage() {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) {
    return (
      <div className="rounded-2xl bg-white p-10 text-center shadow-card">
        <ShieldAlert size={32} className="mx-auto text-[#7D8CCE]" />
        <p className="mt-3 font-medium">Accès réservé à l&apos;encadrement.</p>
      </div>
    );
  }

  // Promoteurs du périmètre (l'API scope un chef de secteur à ses secteurs).
  const usersRes = await listUsers({ role: 'COMMERCIAL', page: 1 }).catch(() => null);
  const promoteurs = (usersRes?.data ?? []).filter((u) => u.isActive);

  const debut = iso(lundi());
  const finExclu = iso(new Date(lundi().getTime() + 7 * 86_400_000));

  const lignes: LignePromoteur[] = await Promise.all(
    promoteurs.map(async (promoteur) => {
      const plannings = (await listMesPlannings(promoteur.id, debut, finExclu)) ?? [];
      const s = statsSemaine(plannings);
      const alerte =
        s.manquees > 0
          ? `${s.manquees} visite${s.manquees > 1 ? 's' : ''} non effectuée${s.manquees > 1 ? 's' : ''}`
          : s.prevues === 0
            ? 'Aucune visite planifiée'
            : null;
      return { promoteur, ...s, alerte };
    }),
  );

  const kpis = {
    promoteurs: lignes.length,
    prevues: lignes.reduce((s, l) => s + l.prevues, 0),
    faites: lignes.reduce((s, l) => s + l.faites, 0),
    alertes: lignes.filter((l) => l.alerte).length,
  };

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <Gauge size={22} className="text-brand dark:text-accent" /> Pilotage
        </h1>
      </div>

      {/* KPIs de la semaine */}
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile icon={Users} label="Promoteurs" value={String(kpis.promoteurs)} />
        <StatTile icon={Footprints} label="Visites prévues" value={String(kpis.prevues)} />
        <StatTile icon={CheckCircle2} label="Effectuées" value={String(kpis.faites)} />
        <StatTile icon={AlertTriangle} label="Alertes" value={String(kpis.alertes)} />
      </section>

      {/* Tableau par promoteur */}
      <div className="overflow-x-auto rounded-2xl bg-white shadow-card">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
            <tr>
              <th className="px-4 py-2.5 font-medium">Promoteur</th>
              <th className="px-4 py-2.5 font-medium">Secteur</th>
              <th className="px-4 py-2.5 text-right font-medium">Prévues</th>
              <th className="px-4 py-2.5 text-right font-medium">Effectuées</th>
              <th className="px-4 py-2.5 text-right font-medium">Non effectuées</th>
              <th className="px-4 py-2.5 text-right font-medium">Taux</th>
              <th className="px-4 py-2.5 font-medium">Statut</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {lignes
              .slice()
              .sort((a, b) => b.manquees - a.manquees || b.prevues - a.prevues)
              .map((l) => {
                const taux = l.prevues > 0 ? Math.round((l.faites / l.prevues) * 100) : null;
                return (
                  <tr key={l.promoteur.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-3 font-medium">{l.promoteur.displayName}</td>
                    <td className="px-4 py-3 text-neutral-500">{l.promoteur.secteur?.nom ?? '—'}</td>
                    <td className="px-4 py-3 text-right tabular-nums">{l.prevues}</td>
                    <td className="px-4 py-3 text-right tabular-nums text-emerald-600 dark:text-emerald-400">{l.faites}</td>
                    <td className={`px-4 py-3 text-right tabular-nums ${l.manquees > 0 ? 'font-semibold text-red-500' : 'text-neutral-400'}`}>
                      {l.manquees}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {taux == null ? (
                        <span className="text-xs text-neutral-400">—</span>
                      ) : (
                        <span className={`text-xs font-semibold ${taux >= 80 ? 'text-emerald-500' : taux >= 50 ? 'text-amber-500' : 'text-red-400'}`}>
                          {taux} %
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {l.alerte ? (
                        <span className="inline-flex items-center gap-1 rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-500">
                          <AlertTriangle size={11} /> {l.alerte}
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-600 dark:text-emerald-400">
                          <CheckCircle2 size={11} /> En ligne avec le planning
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })}
            {lignes.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-neutral-400">
                  Aucun promoteur dans votre périmètre.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
