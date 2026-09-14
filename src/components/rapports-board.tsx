'use client';

import { useMemo, useState } from 'react';
import { X, MapPinned, CalendarDays, Smartphone, CheckCircle2, XCircle, PlusCircle, Target, ChevronLeft, ChevronRight } from 'lucide-react';
import { KpiTile } from './kpi-tile';

const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
function isoToDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}
function dateToIso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function shiftWeek(iso: string, days: number): string {
  const d = isoToDate(iso);
  d.setDate(d.getDate() + days);
  return dateToIso(d);
}
function weekLabel(iso: string): string {
  return `Semaine du ${WEEK_FMT.format(isoToDate(iso))}`;
}

type Statut = 'PREVISION' | 'COMPLET';

type DR = { nom: string; initials: string; color: string; region: string; role: string };

const DRS: Record<string, DR> = {
  GS: { nom: 'Grégory Sylvestre', initials: 'GS', color: 'bg-emerald-500', region: 'Nord-Ouest', role: 'DR' },
  CR: { nom: 'Cindy Ryssen', initials: 'CR', color: 'bg-fuchsia-500', region: 'Nord-Est', role: 'DR' },
  AR: { nom: 'Adrien Richard', initials: 'AR', color: 'bg-sky-500', region: 'Sud-Ouest', role: 'DR' },
  MD: { nom: 'Marie Dubois', initials: 'MD', color: 'bg-rose-500', region: 'Sud-Est', role: 'DR' },
  LM: { nom: 'Lucas Marchand', initials: 'LM', color: 'bg-orange-500', region: 'Sud-Ouest', role: 'CS' },
};

type Magasin = { nom: string; ville: string; prevu: boolean; realise: boolean; note?: string };

type Rapport = {
  id: string;
  dr: string;
  semaine: string;
  statut: Statut;
  magasins: Magasin[];
  synthese: string;
};

// Prototype — la prévision et le bilan seront saisis sur l'app mobile.
const INIT: Rapport[] = [
  {
    id: 'r1', dr: 'GS', semaine: '2025-05-19', statut: 'PREVISION', synthese: '',
    magasins: [
      { nom: 'Système U Lyon Vaise', ville: 'Lyon', prevu: true, realise: false },
      { nom: 'Leclerc Rennes', ville: 'Rennes', prevu: true, realise: false },
      { nom: 'Cora Bruay', ville: 'Bruay', prevu: true, realise: false },
      { nom: 'Intermarché La Mézière', ville: 'La Mézière', prevu: true, realise: false },
      { nom: 'Auchan Roncq', ville: 'Roncq', prevu: true, realise: false },
    ],
  },
  {
    id: 'r2', dr: 'LM', semaine: '2025-05-19', statut: 'PREVISION', synthese: '',
    magasins: [
      { nom: 'Auchan Vert Saint-Denis', ville: 'Saint-Denis', prevu: true, realise: false },
      { nom: 'Carrefour Market Nantes', ville: 'Nantes', prevu: true, realise: false },
      { nom: 'Casino Nice', ville: 'Nice', prevu: true, realise: false },
    ],
  },
  {
    id: 'r3', dr: 'AR', semaine: '2025-05-12', statut: 'COMPLET',
    synthese: 'Bonne semaine sur le Sud-Ouest, objectif de visites tenu. Une opportunité de référencement détectée chez Auchan.',
    magasins: [
      { nom: 'Leclerc Blagnac', ville: 'Blagnac', prevu: true, realise: true },
      { nom: 'Auchan Vert Saint-Denis', ville: 'Saint-Denis', prevu: true, realise: true, note: 'Opportunité PEM 32 K€' },
      { nom: 'Intermarché Vannes', ville: 'Vannes', prevu: true, realise: true },
      { nom: 'Système U Toulouse', ville: 'Toulouse', prevu: true, realise: false, note: 'Reporté — magasin fermé' },
      { nom: 'Cora Albi', ville: 'Albi', prevu: false, realise: true, note: 'Visite opportuniste' },
    ],
  },
  {
    id: 'r4', dr: 'MD', semaine: '2025-05-12', statut: 'COMPLET',
    synthese: 'Sud-Est en difficulté : baisse de CA confirmée sur Leclerc Évry, plan d’action lancé.',
    magasins: [
      { nom: 'Leclerc Évry 2', ville: 'Évry', prevu: true, realise: true, note: 'Baisse CA -23 %' },
      { nom: 'Cora Lens', ville: 'Lens', prevu: true, realise: true },
      { nom: 'Carrefour Market Reims', ville: 'Reims', prevu: true, realise: false, note: 'Manque de temps' },
      { nom: 'Auchan Dijon', ville: 'Dijon', prevu: true, realise: false },
    ],
  },
  {
    id: 'r5', dr: 'CR', semaine: '2025-05-12', statut: 'COMPLET',
    synthese: 'Nord-Est régulier, aucune alerte majeure. Prospection lancée sur deux points de vente.',
    magasins: [
      { nom: 'Auchan Villeneuve', ville: 'Villeneuve', prevu: true, realise: true },
      { nom: 'Système U Amiens', ville: 'Amiens', prevu: true, realise: true },
      { nom: 'Match Metz', ville: 'Metz', prevu: true, realise: true },
      { nom: 'Cora Reims', ville: 'Reims', prevu: false, realise: true, note: 'Prospection' },
    ],
  },
  {
    id: 'r6', dr: 'GS', semaine: '2025-05-05', statut: 'COMPLET',
    synthese: 'Couverture maintenue sur le Nord-Ouest, réassort validé chez Cora.',
    magasins: [
      { nom: 'Cora Bruay', ville: 'Bruay', prevu: true, realise: true },
      { nom: 'Leclerc Rennes', ville: 'Rennes', prevu: true, realise: true },
      { nom: 'Système U Lyon Vaise', ville: 'Lyon', prevu: true, realise: true },
      { nom: 'Intermarché Brest', ville: 'Brest', prevu: true, realise: false },
    ],
  },
];

const chipBase = 'inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition';
const chipOff = 'border-neutral-200 bg-white text-neutral-600 hover:border-brand/50 hover:text-brand dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-300 dark:hover:border-brand';
const chipOn = 'border-brand bg-brand text-white shadow-sm';

function stats(r: Rapport) {
  const prevus = r.magasins.filter((m) => m.prevu).length;
  const realises = r.magasins.filter((m) => m.prevu && m.realise).length;
  const horsPrev = r.magasins.filter((m) => !m.prevu && m.realise).length;
  const taux = prevus > 0 ? Math.round((realises / prevus) * 100) : null;
  return { prevus, realises, horsPrev, taux };
}

function Avatar({ dr }: { dr: DR }) {
  return <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[10px] font-bold text-white ${dr.color}`}>{dr.initials}</span>;
}

function StatutBadge({ statut }: { statut: Statut }) {
  return statut === 'PREVISION' ? (
    <span className="inline-flex rounded-full bg-amber-500/15 px-2 py-0.5 text-xs font-medium text-amber-600 dark:text-amber-400">Prévision</span>
  ) : (
    <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/12 px-2 py-0.5 text-xs font-medium text-emerald-600 dark:text-emerald-400"><CheckCircle2 size={11} /> Clôturé</span>
  );
}

export function RapportsBoard() {
  const weeks = useMemo(() => [...new Set(INIT.map((r) => r.semaine))].sort(), []);
  const [weekIso, setWeekIso] = useState(() => weeks.at(-1) ?? dateToIso(new Date()));
  const [drFilter, setDrFilter] = useState<'ALL' | string>('ALL');
  const [statutFilter, setStatutFilter] = useState<'ALL' | Statut>('ALL');
  const [selected, setSelected] = useState<Rapport | null>(null);

  const weekReports = useMemo(() => INIT.filter((r) => r.semaine === weekIso), [weekIso]);

  const kpis = useMemo(() => {
    const complets = weekReports.filter((r) => r.statut === 'COMPLET');
    const tauxMoyen = complets.length
      ? Math.round(complets.reduce((s, r) => s + (stats(r).taux ?? 0), 0) / complets.length)
      : null;
    return {
      total: weekReports.length,
      previsions: weekReports.filter((r) => r.statut === 'PREVISION').length,
      complets: complets.length,
      tauxMoyen,
    };
  }, [weekReports]);

  const filtered = useMemo(
    () => weekReports.filter((r) => (drFilter === 'ALL' || r.dr === drFilter) && (statutFilter === 'ALL' || r.statut === statutFilter)),
    [weekReports, drFilter, statutFilter],
  );

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Rapports d&apos;activité</h1>
          <p className="mt-0.5 flex items-center gap-1.5 text-sm text-neutral-500">
            <Smartphone size={14} /> Prévision en début de semaine, bilan en fin de semaine — saisis sur l&apos;app mobile.
          </p>
        </div>
        <div className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
          <button type="button" onClick={() => setWeekIso(shiftWeek(weekIso, -7))} className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800" aria-label="Semaine précédente">
            <ChevronLeft size={16} />
          </button>
          <span className="min-w-52 px-1 text-center text-sm font-semibold">{weekLabel(weekIso)}</span>
          <button type="button" onClick={() => setWeekIso(shiftWeek(weekIso, 7))} className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800" aria-label="Semaine suivante">
            <ChevronRight size={16} />
          </button>
        </div>
      </div>

      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile label="Rapports" value={String(kpis.total)} sub="au total" />
        <KpiTile label="Prévisions en cours" value={String(kpis.previsions)} pill={kpis.previsions > 0 ? { text: 'bilan attendu', tone: 'warn' } : { text: 'aucune', tone: 'up' }} />
        <KpiTile label="Semaines clôturées" value={String(kpis.complets)} sub="bilan reçu" />
        <KpiTile label="Taux réalisation moy." value={kpis.tauxMoyen != null ? `${kpis.tauxMoyen}%` : '—'} pill={kpis.tauxMoyen != null ? { text: kpis.tauxMoyen >= 80 ? 'bon' : 'à suivre', tone: kpis.tauxMoyen >= 80 ? 'up' : 'warn' } : undefined} />
      </section>

      <div className="flex flex-col gap-2.5">
        <div className="flex flex-wrap items-center gap-2">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">Auteur</span>
          <button type="button" onClick={() => setDrFilter('ALL')} className={`${chipBase} ${drFilter === 'ALL' ? chipOn : chipOff}`}>Tous</button>
          {Object.entries(DRS).map(([code, dr]) => (
            <button key={code} type="button" onClick={() => setDrFilter(code)} className={`${chipBase} ${drFilter === code ? chipOn : chipOff}`}>{dr.nom}</button>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">Statut</span>
          <button type="button" onClick={() => setStatutFilter('ALL')} className={`${chipBase} ${statutFilter === 'ALL' ? chipOn : chipOff}`}>Tous</button>
          <button type="button" onClick={() => setStatutFilter('PREVISION')} className={`${chipBase} ${statutFilter === 'PREVISION' ? chipOn : chipOff}`}>Prévisions <b className="opacity-60">{kpis.previsions}</b></button>
          <button type="button" onClick={() => setStatutFilter('COMPLET')} className={`${chipBase} ${statutFilter === 'COMPLET' ? chipOn : chipOff}`}>Clôturés</button>
        </div>
      </div>

      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">Auteur</th>
              <th className="px-4 py-2.5 font-medium">Région</th>
              <th className="px-4 py-2.5 text-right font-medium">Prévus</th>
              <th className="px-4 py-2.5 text-right font-medium">Réalisés</th>
              <th className="px-4 py-2.5 text-right font-medium">Taux</th>
              <th className="px-4 py-2.5 font-medium">Statut</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {filtered.map((r) => {
              const dr = DRS[r.dr];
              const s = stats(r);
              return (
                <tr key={r.id} onClick={() => setSelected(r)} className="cursor-pointer hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                  <td className="px-4 py-3">
                    <span className="flex items-center gap-2">
                      <Avatar dr={dr} />
                      <span>
                        <span className="font-medium">{dr.nom}</span>
                        <span className="ml-1.5 rounded bg-neutral-100 px-1 py-0.5 text-[10px] font-medium text-neutral-500 dark:bg-navy-800">{dr.role}</span>
                      </span>
                    </span>
                  </td>
                  <td className="px-4 py-3 text-neutral-500">{dr.region}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{s.prevus}</td>
                  <td className="px-4 py-3 text-right tabular-nums">{r.statut === 'COMPLET' ? s.realises : '—'}</td>
                  <td className="px-4 py-3 text-right">
                    {r.statut === 'COMPLET' && s.taux != null ? (
                      <span className={`font-semibold ${s.taux >= 80 ? 'text-emerald-500' : s.taux >= 50 ? 'text-amber-500' : 'text-red-400'}`}>{s.taux}%</span>
                    ) : (
                      <span className="text-neutral-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3"><StatutBadge statut={r.statut} /></td>
                </tr>
              );
            })}
            {filtered.length === 0 ? (
              <tr><td colSpan={6} className="px-4 py-10 text-center text-neutral-400">Aucune donnée pour cette semaine.</td></tr>
            ) : null}
          </tbody>
        </table>
      </div>

      {selected ? <RapportModal rapport={selected} onClose={() => setSelected(null)} /> : null}
    </div>
  );
}

function RapportModal({ rapport, onClose }: { rapport: Rapport; onClose: () => void }) {
  const dr = DRS[rapport.dr];
  const s = stats(rapport);
  const complet = rapport.statut === 'COMPLET';
  const prevus = rapport.magasins.filter((m) => m.prevu);
  const horsPrev = rapport.magasins.filter((m) => !m.prevu && m.realise);

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-10" onClick={onClose}>
      <div className="w-full max-w-2xl rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between border-b border-neutral-100 px-5 py-4 dark:border-navy-700">
          <div className="flex items-center gap-3">
            <Avatar dr={dr} />
            <div>
              <h2 className="flex items-center gap-2 text-lg font-bold">{dr.nom} <StatutBadge statut={rapport.statut} /></h2>
              <p className="flex items-center gap-2 text-xs text-neutral-400">
                <span className="inline-flex items-center gap-1"><MapPinned size={12} /> {dr.region}</span>
                <span className="inline-flex items-center gap-1"><CalendarDays size={12} /> {rapport.semaine}</span>
              </p>
            </div>
          </div>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer"><X size={18} /></button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-4">
          {/* KPIs prévu / réalisé */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <MiniStat icon={CalendarDays} label="Prévus" value={String(s.prevus)} />
            <MiniStat icon={CheckCircle2} label="Réalisés" value={complet ? String(s.realises) : '—'} tone="text-emerald-500" />
            <MiniStat icon={Target} label="Taux" value={complet && s.taux != null ? `${s.taux}%` : '—'} tone={complet && s.taux != null ? (s.taux >= 80 ? 'text-emerald-500' : s.taux >= 50 ? 'text-amber-500' : 'text-red-400') : ''} />
            <MiniStat icon={PlusCircle} label="Hors prévision" value={complet ? String(s.horsPrev) : '—'} tone="text-sky-500" />
          </div>

          {!complet ? (
            <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
              Prévision soumise — le bilan sera renseigné en fin de semaine.
            </p>
          ) : null}

          {/* Prévision de la semaine */}
          <div>
            <h3 className="mb-2 text-sm font-semibold">
              {complet ? 'Prévu vs réalisé' : 'Magasins prévus cette semaine'}
            </h3>
            <ul className="flex flex-col gap-1.5">
              {prevus.map((m, i) => (
                <li key={i} className="flex items-center gap-2.5 rounded-lg border border-neutral-100 px-3 py-2 dark:border-navy-700">
                  {!complet ? (
                    <span className="h-2 w-2 shrink-0 rounded-full bg-neutral-300" />
                  ) : m.realise ? (
                    <CheckCircle2 size={15} className="shrink-0 text-emerald-500" />
                  ) : (
                    <XCircle size={15} className="shrink-0 text-red-400" />
                  )}
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{m.nom}</p>
                    <p className="truncate text-[11px] text-neutral-400">
                      {m.ville}
                      {m.note ? ` · ${m.note}` : ''}
                    </p>
                  </div>
                  {complet ? (
                    <span className={`shrink-0 text-xs font-medium ${m.realise ? 'text-emerald-500' : 'text-red-400'}`}>
                      {m.realise ? 'Visité' : 'Non visité'}
                    </span>
                  ) : (
                    <span className="shrink-0 text-xs text-neutral-400">Prévu</span>
                  )}
                </li>
              ))}
            </ul>
          </div>

          {/* Hors prévision */}
          {complet && horsPrev.length > 0 ? (
            <div>
              <h3 className="mb-2 flex items-center gap-1.5 text-sm font-semibold text-sky-600 dark:text-sky-400">
                <PlusCircle size={14} /> Visites hors prévision
              </h3>
              <ul className="flex flex-col gap-1.5">
                {horsPrev.map((m, i) => (
                  <li key={i} className="flex items-center gap-2.5 rounded-lg border border-sky-100 bg-sky-50/50 px-3 py-2 dark:border-navy-700 dark:bg-navy-800/40">
                    <PlusCircle size={14} className="shrink-0 text-sky-500" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{m.nom}</p>
                      <p className="truncate text-[11px] text-neutral-400">{m.ville}{m.note ? ` · ${m.note}` : ''}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {/* Synthèse (bilan) */}
          {complet && rapport.synthese ? (
            <div>
              <h3 className="mb-1 text-sm font-semibold">Bilan de la semaine</h3>
              <p className="text-sm text-neutral-600 dark:text-neutral-300">{rapport.synthese}</p>
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function MiniStat({ icon: Icon, label, value, tone }: { icon: typeof MapPinned; label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
      <div className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><Icon size={13} /> {label}</div>
      <p className={`mt-1 text-lg font-bold tabular-nums ${tone ?? ''}`}>{value}</p>
    </div>
  );
}
