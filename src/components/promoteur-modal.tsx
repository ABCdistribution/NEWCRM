'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import {
  X,
  CalendarDays,
  CheckCircle2,
  AlertCircle,
  FileText,
  Target,
  Wallet,
  Route,
} from 'lucide-react';
import { getPromoteurSemaine, getRapportsMembre, type RapportHebdo } from '@/lib/equipe-actions';
import type { PlanningItem } from '@/lib/api';
import type { Membre } from './mon-equipe-board';
import { ClassBadge } from './class-badge';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const DAY = new Intl.DateTimeFormat('fr-FR', { weekday: 'short', day: '2-digit', month: 'short' });

function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function statut(v: PlanningItem, today: string): 'faite' | 'manquee' | 'prevue' {
  if (v.fait) return 'faite';
  const d = new Date(v.datePassage);
  const jour = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return jour < today ? 'manquee' : 'prevue';
}

const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

function Stat({
  icon: Icon,
  label,
  value,
  tone,
}: {
  icon: typeof Wallet;
  label: string;
  value: string;
  tone?: string;
}) {
  return (
    <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
      <div className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400">
        <Icon size={13} /> {label}
      </div>
      <p className={`mt-1 text-lg font-bold tabular-nums ${tone ?? ''}`}>{value}</p>
    </div>
  );
}

export function PromoteurModal({ membre, onClose }: { membre: Membre; onClose: () => void }) {
  const [items, setItems] = useState<PlanningItem[] | null>(null);
  const [rapports, setRapports] = useState<RapportHebdo[] | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    let alive = true;
    setItems(null);
    setRapports(null);
    setError(false);
    getPromoteurSemaine(membre.id).then((r) => {
      if (!alive) return;
      setItems(r.items);
      setError(r.error);
    });
    getRapportsMembre(membre.id).then((r) => alive && setRapports(r));
    return () => {
      alive = false;
    };
  }, [membre.id]);

  const today = todayIso();
  const faites = items?.filter((v) => v.fait).length ?? 0;
  const manquees = items?.filter((v) => statut(v, today) === 'manquee').length ?? 0;
  const zone = membre.secteur ? `${membre.secteur.nom} (${membre.secteur.code})` : membre.region?.nom ?? '—';

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-12" onClick={onClose}>
      <div className="w-full max-w-xl rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        {/* En-tête */}
        <div className="flex items-start justify-between border-b border-neutral-100 px-5 py-4 dark:border-navy-700">
          <div>
            <h2 className="text-lg font-bold">{membre.displayName}</h2>
            <p className="text-xs text-neutral-400">{zone}</p>
          </div>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-4">
          {/* Alertes */}
          {manquees > 0 ? (
            <p className="flex items-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
              <AlertCircle size={15} /> {manquees} visite{manquees > 1 ? 's' : ''} manquée{manquees > 1 ? 's' : ''} cette semaine.
            </p>
          ) : null}

          {/* KPIs */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Stat icon={Wallet} label="CA mois" value={membre.ca != null ? EUR.format(membre.ca) : '—'} tone="text-brand dark:text-accent" />
            <Stat icon={Target} label="Objectif" value={membre.tauxPct != null ? `${membre.tauxPct}%` : '—'} tone={membre.tauxPct != null ? (membre.tauxPct >= 100 ? 'text-emerald-500' : membre.tauxPct >= 70 ? 'text-amber-500' : 'text-red-400') : ''} />
            <Stat icon={CalendarDays} label="Planifiées" value={items ? String(items.length) : '…'} />
            <Stat icon={CheckCircle2} label="Effectuées" value={items ? String(faites) : '…'} tone="text-emerald-500" />
          </div>

          {/* Rapports d'activité du chef de secteur */}
          <div>
            <h3 className="mb-2 flex items-center gap-1.5 text-sm font-semibold">
              <FileText size={14} className="text-brand dark:text-accent" /> Rapports d&apos;activité
            </h3>
            {rapports === null ? (
              <p className="py-3 text-center text-sm text-neutral-400">Chargement…</p>
            ) : rapports.length === 0 ? (
              <p className="rounded-lg border border-dashed border-neutral-200 px-3 py-3 text-sm text-neutral-400 dark:border-navy-700">
                Aucune activité planifiée sur les 4 dernières semaines.
              </p>
            ) : (
            <ul className="flex flex-col gap-1.5">
              {rapports.map((r) => (
                <li key={r.semaine}>
                <Link
                  href={`/pilotage/mon-equipe/${membre.id}/planning?semaine=${r.semaine}`}
                  className="block rounded-lg border border-neutral-100 px-3 py-2 transition hover:border-brand hover:bg-neutral-50 dark:border-navy-700 dark:hover:border-accent dark:hover:bg-navy-800/50"
                  title="Ouvrir cette semaine dans le planning"
                >
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-medium">Semaine du {WEEK_FMT.format(new Date(r.semaine))}</span>
                    {r.statut === 'PREVISION' ? (
                      <span className="rounded-full bg-sky-500/12 px-2 py-0.5 text-[11px] font-semibold text-sky-600 dark:text-sky-400">
                        Prévision · {r.prevus} magasins prévus
                      </span>
                    ) : (
                      <span className="rounded-full bg-emerald-500/12 px-2 py-0.5 text-[11px] font-semibold text-emerald-600 dark:text-emerald-400">
                        Rapport complet · {r.realises}/{r.prevus} réalisés
                      </span>
                    )}
                  </div>
                  {r.synthese ? <p className="mt-1 text-xs text-neutral-500">{r.synthese}</p> : null}
                </Link>
                </li>
              ))}
            </ul>
            )}
          </div>

          {/* Visites de la semaine */}
          <div>
            <div className="mb-2 flex items-center justify-between">
              <h3 className="text-sm font-semibold">Visites planifiées cette semaine</h3>
              <Link
                href={`/pilotage/mon-equipe/${membre.id}/planning`}
                className="inline-flex items-center gap-1 text-xs font-medium text-brand hover:underline dark:text-accent"
              >
                Voir le planning <Route size={12} />
              </Link>
            </div>

            {items === null ? (
              <p className="py-6 text-center text-sm text-neutral-400">Chargement…</p>
            ) : error ? (
              <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">Planning indisponible — l&apos;API est-elle démarrée ?</p>
            ) : items.length === 0 ? (
              <p className="rounded-lg border border-dashed border-neutral-200 py-6 text-center text-sm text-neutral-400 dark:border-navy-700">
                Aucune visite planifiée cette semaine.
              </p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {items
                  .slice()
                  .sort((a, b) => a.datePassage.localeCompare(b.datePassage))
                  .map((v) => {
                    const s = statut(v, today);
                    const dot = s === 'faite' ? 'bg-emerald-400' : s === 'manquee' ? 'bg-red-400' : 'bg-neutral-300';
                    return (
                      <li key={v.id} className="flex items-center gap-2.5 rounded-lg border border-neutral-100 px-3 py-2 dark:border-navy-700">
                        <span className={`h-2 w-2 shrink-0 rounded-full ${dot}`} />
                        <ClassBadge value={v.client.niveauClass} size="xs" />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-medium">{v.client.enseigne}</p>
                          {v.client.ville ? <p className="truncate text-[11px] text-neutral-400">{v.client.ville}</p> : null}
                        </div>
                        <span className="shrink-0 text-xs text-neutral-400">{DAY.format(new Date(v.datePassage))}</span>
                      </li>
                    );
                  })}
              </ul>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
