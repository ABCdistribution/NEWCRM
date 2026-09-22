'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import {
  AlertTriangle,
  CalendarClock,
  CalendarDays,
  CheckCircle2,
  ExternalLink,
  Footprints,
  Store,
  Wallet,
  X,
} from 'lucide-react';
import { ClassBadge } from './class-badge';
import dynamic from 'next/dynamic';
import { getSuiviMagasin, type SuiviMagasin } from '@/lib/magasin-actions';
import type { MagasinSuiviRow, MagasinGeoPoint, ProspectRow } from '@/lib/api';
import { MagasinContactActions } from './magasin-contact-actions';
import { MagasinTourneeButton } from './magasin-tournee-button';

// Leaflet touche window : chargement client uniquement.
const CarteSecteur = dynamic(() => import('./carte-secteur').then((m) => m.CarteSecteur), {
  ssr: false,
  loading: () => <div className="h-[560px] w-full animate-pulse rounded-2xl bg-neutral-100 dark:bg-navy-800" />,
});

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const DATE = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: '2-digit', month: 'short' });

const CLASSES = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

const ETAT_BADGE = {
  ok: { label: 'À jour', cls: 'bg-emerald-500/12 text-emerald-600 dark:text-emerald-400', Icon: CheckCircle2 },
  attention: { label: 'Attention', cls: 'bg-amber-500/15 text-amber-600 dark:text-amber-400', Icon: AlertTriangle },
  alerte: { label: 'Alerte', cls: 'bg-red-500/12 text-red-500', Icon: AlertTriangle },
} as const;

function Delta({ pct }: { pct: number | null }) {
  if (pct == null) return null;
  const up = pct >= 0;
  return (
    <span className={`text-[11px] font-semibold ${up ? 'text-emerald-500' : 'text-red-400'}`}>
      {up ? '+' : ''}{pct}%
    </span>
  );
}

/** Fiche de suivi rapide d'un magasin : tournées effectuées + à venir, promoteur en charge. */
function MagasinModal({ magasin, onClose }: { magasin: MagasinSuiviRow; onClose: () => void }) {
  const [suivi, setSuivi] = useState<SuiviMagasin | null>(null);

  useEffect(() => {
    let alive = true;
    setSuivi(null);
    getSuiviMagasin(magasin.id).then((s) => alive && setSuivi(s));
    return () => {
      alive = false;
    };
  }, [magasin.id]);

  const etat = ETAT_BADGE[magasin.etat];

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-12" onClick={onClose}>
      <div className="w-full max-w-xl rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        {/* En-tête : identité + classification mise en avant */}
        <div className="flex items-start justify-between gap-3 border-b border-neutral-100 px-5 py-4 dark:border-navy-700">
          <div className="flex items-center gap-3">
            <span className="scale-150"><ClassBadge value={magasin.niveauClass} /></span>
            <div>
              <h2 className="text-lg font-bold">{magasin.enseigne}</h2>
              <p className="text-xs text-neutral-400">
                {[magasin.codePostal, magasin.ville].filter(Boolean).join(' ')} · code {magasin.codeAs400}
                {magasin.cs ? ` · promoteur : ${magasin.cs.displayName}` : ' · aucun promoteur en charge'}
              </p>
            </div>
          </div>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-4">
          {/* Contact direct + planification dans mon planning */}
          <div className="flex flex-wrap items-center justify-between gap-2">
            <MagasinContactActions clientId={magasin.id} telephone={magasin.tel1} email={magasin.email} />
            <MagasinTourneeButton clientId={magasin.id} />
          </div>

          {/* KPIs du magasin */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
              <p className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><Wallet size={13} /> CA mois</p>
              <p className="mt-1 text-lg font-bold tabular-nums">{EUR.format(magasin.caMois)} <Delta pct={magasin.deltaPct} /></p>
            </div>
            <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
              <p className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><Footprints size={13} /> Dern. tournée</p>
              <p className={`mt-1 text-lg font-bold tabular-nums ${magasin.enRetard ? 'text-red-500' : ''}`}>
                {magasin.derniereVisiteJours != null ? `${magasin.derniereVisiteJours} j` : '—'}
              </p>
            </div>
            <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
              <p className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><CalendarDays size={13} /> Périodicité</p>
              <p className="mt-1 truncate text-sm font-semibold">{magasin.periodicite ?? '—'}</p>
            </div>
            <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
              <p className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><etat.Icon size={13} /> État</p>
              <p className="mt-1"><span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${etat.cls}`}>{etat.label}</span></p>
            </div>
          </div>

          {/* Tournées à venir */}
          <div>
            <h3 className="mb-2 flex items-center gap-1.5 text-sm font-semibold">
              <CalendarClock size={14} className="text-brand dark:text-accent" /> Tournées à venir
            </h3>
            {suivi === null ? (
              <p className="py-3 text-center text-sm text-neutral-400">Chargement…</p>
            ) : suivi.aVenir.length === 0 ? (
              <p className="rounded-lg border border-dashed border-neutral-200 px-3 py-3 text-sm text-neutral-400 dark:border-navy-700">
                Aucune tournée planifiée.
              </p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {suivi.aVenir.map((v) => (
                  <li key={v.id} className="flex items-center gap-2.5 rounded-lg border border-neutral-100 px-3 py-2 text-sm dark:border-navy-700">
                    <span className="h-2 w-2 shrink-0 rounded-full bg-sky-400" />
                    <span className="font-medium">{DATE.format(new Date(v.datePassage))}</span>
                    <span className="ml-auto text-xs text-neutral-400">{v.promoteur?.displayName ?? '—'}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {/* Tournées effectuées */}
          <div>
            <h3 className="mb-2 flex items-center gap-1.5 text-sm font-semibold">
              <Footprints size={14} className="text-emerald-500" /> Dernières tournées effectuées
            </h3>
            {suivi === null ? (
              <p className="py-3 text-center text-sm text-neutral-400">Chargement…</p>
            ) : suivi.effectuees.length === 0 ? (
              <p className="rounded-lg border border-dashed border-neutral-200 px-3 py-3 text-sm text-neutral-400 dark:border-navy-700">
                Aucune tournée enregistrée dans ce magasin.
              </p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {suivi.effectuees.map((v) => (
                  <li key={v.id} className="flex items-center gap-2.5 rounded-lg border border-neutral-100 px-3 py-2 text-sm dark:border-navy-700">
                    <span className="h-2 w-2 shrink-0 rounded-full bg-emerald-400" />
                    <span className="font-medium">{DATE.format(new Date(v.createdAt))}</span>
                    <span className="text-xs text-neutral-400">
                      DN {v.dnAbc ?? '—'} / conc. {v.dnConcurrence ?? '—'}
                      {v.pem ? ' · PEM' : ''}
                    </span>
                    <span className="ml-auto text-xs text-neutral-400">{v.promoteur.displayName}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <Link
            href={`/pilotage/clients/${magasin.id}`}
            className="inline-flex items-center gap-1.5 self-end text-xs font-medium text-brand hover:underline dark:text-accent"
          >
            Ouvrir la fiche complète du magasin <ExternalLink size={12} />
          </Link>
        </div>
      </div>
    </div>
  );
}

/** Gestion des magasins secteur : classification, KPI, suivi des tournées, promoteur en charge. */
export function MagasinsSecteurBoard({
  magasins,
  points,
  prospects,
}: {
  magasins: MagasinSuiviRow[];
  points: MagasinGeoPoint[];
  prospects: ProspectRow[];
}) {
  const [vue, setVue] = useState<'tableau' | 'carte'>('tableau');
  const [classe, setClasse] = useState<'ALL' | string>('ALL');
  const [etat, setEtat] = useState<'ALL' | 'ok' | 'attention' | 'alerte'>('ALL');
  const [selected, setSelected] = useState<MagasinSuiviRow | null>(null);

  const kpis = useMemo(() => {
    const parClasse = new Map<string, number>();
    for (const m of magasins) {
      const c = m.niveauClass ?? '—';
      parClasse.set(c, (parClasse.get(c) ?? 0) + 1);
    }
    return {
      total: magasins.length,
      caMois: magasins.reduce((s, m) => s + m.caMois, 0),
      enRetard: magasins.filter((m) => m.enRetard).length,
      alertes: magasins.filter((m) => m.etat === 'alerte').length,
      parClasse,
    };
  }, [magasins]);

  const filtres = useMemo(() => {
    return magasins
      .filter((m) => (classe === 'ALL' || m.niveauClass === classe) && (etat === 'ALL' || m.etat === etat))
      .sort((a, b) => (a.niveauClass ?? 'Z').localeCompare(b.niveauClass ?? 'Z') || b.caMois - a.caMois);
  }, [magasins, classe, etat]);

  const chip = (active: boolean) =>
    `rounded-full border px-2.5 py-1 text-xs font-semibold transition ${
      active
        ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
        : 'border-neutral-200 bg-white text-neutral-600 hover:border-brand/50 dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-300'
    }`;

  return (
    <div className="flex flex-col gap-4">
      {/* Bascule Tableau / Carte */}
      <div className="flex items-center gap-1 self-start rounded-xl bg-white p-1 shadow-card">
        {(['tableau', 'carte'] as const).map((v) => (
          <button
            key={v}
            type="button"
            onClick={() => setVue(v)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
              vue === v
                ? 'bg-brand text-white dark:bg-accent dark:text-brand'
                : 'text-neutral-500 hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-navy-800'
            }`}
          >
            {v === 'tableau' ? 'Tableau' : 'Carte du secteur'}
          </button>
        ))}
      </div>

      {vue === 'carte' ? (
        <CarteSecteur points={points} prospects={prospects} />
      ) : (
        <>
      {/* Filtres : classification mise en avant */}
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Classe</span>
        <button type="button" onClick={() => setClasse('ALL')} className={chip(classe === 'ALL')}>
          Toutes <b className="opacity-60">{kpis.total}</b>
        </button>
        {CLASSES.filter((c) => kpis.parClasse.has(c)).map((c) => (
          <button key={c} type="button" onClick={() => setClasse(c)} className={chip(classe === c)}>
            {c} <b className="opacity-60">{kpis.parClasse.get(c)}</b>
          </button>
        ))}
        <span className="mx-1 hidden h-5 w-px bg-neutral-200 sm:block dark:bg-navy-700" />
        <select
          value={etat}
          onChange={(e) => setEtat(e.target.value as typeof etat)}
          className="rounded-full border border-neutral-200 bg-white px-3 py-1.5 text-xs font-medium text-neutral-600 outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-300"
          aria-label="Filtrer par état"
        >
          <option value="ALL">Tous les états</option>
          <option value="ok">À jour</option>
          <option value="attention">Attention</option>
          <option value="alerte">Alerte</option>
        </select>

      </div>

      {/* Tableau */}
      <div className="overflow-x-auto rounded-2xl bg-white shadow-card">
        <table className="w-full min-w-[860px] text-sm">
          <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
            <tr>
              <th className="px-4 py-2.5 font-medium">Magasin</th>
              <th className="px-4 py-2.5 text-center font-medium">Classe</th>
              <th className="px-4 py-2.5 font-medium">Promoteur en charge</th>
              <th className="px-4 py-2.5 text-right font-medium">CA mois</th>
              <th className="px-4 py-2.5 text-right font-medium">Dern. tournée</th>
              <th className="px-4 py-2.5 font-medium">Périodicité</th>
              <th className="px-4 py-2.5 font-medium">État</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {filtres.map((m) => {
              const e = ETAT_BADGE[m.etat];
              return (
                <tr
                  key={m.id}
                  onClick={() => setSelected(m)}
                  className="cursor-pointer hover:bg-neutral-50 dark:hover:bg-navy-800/50"
                  title="Voir le suivi du magasin"
                >
                  <td className="px-4 py-3">
                    <p className="font-medium">{m.enseigne}</p>
                    <p className="text-[11px] text-neutral-400">
                      {[m.codePostal, m.ville].filter(Boolean).join(' ')} · {m.codeAs400}
                    </p>
                  </td>
                  <td className="px-4 py-3 text-center"><ClassBadge value={m.niveauClass} /></td>
                  <td className="px-4 py-3 text-neutral-600 dark:text-neutral-300">{m.cs?.displayName ?? '—'}</td>
                  <td className="px-4 py-3 text-right">
                    <span className="font-semibold tabular-nums dark:text-accent">{EUR.format(m.caMois)}</span>{' '}
                    <Delta pct={m.deltaPct} />
                  </td>
                  <td className={`px-4 py-3 text-right tabular-nums ${m.enRetard ? 'font-semibold text-red-500' : ''}`}>
                    {m.derniereVisiteJours != null ? `${m.derniereVisiteJours} j` : '—'}
                  </td>
                  <td className="px-4 py-3 text-xs text-neutral-500">{m.periodicite ?? '—'}</td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${e.cls}`}>
                      <e.Icon size={11} /> {e.label}
                      {m.alertes > 0 ? ` · ${m.alertes}` : ''}
                    </span>
                  </td>
                </tr>
              );
            })}
            {filtres.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-neutral-400">Aucun magasin pour ces filtres.</td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>

        </>
      )}

      {selected ? <MagasinModal magasin={selected} onClose={() => setSelected(null)} /> : null}
    </div>
  );
}
