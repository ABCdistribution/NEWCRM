'use client';

import { useMemo, useState, useTransition } from 'react';
import { AlertCircle, BellRing, CheckCircle2, GripVertical, Repeat, Search, Store, Trash2, X } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { AddVisit } from './add-visit';
import { dropPlanning, movePlanning, removePlanning, relancerVisite } from '@/lib/planning-actions';
import type { PlanningItem, ClientRow } from '@/lib/api';

type Day = { date: string; nom: string; label: string };

/** yyyy-mm-dd local du jour courant. */
function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** État visuel d'une visite : effectuée / manquée (passée non faite) / à venir. */
function statutVisite(v: { fait: boolean; datePassage: string }, aujourdhui: string) {
  if (v.fait) return 'faite' as const;
  const d = new Date(v.datePassage);
  const jour = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return jour < aujourdhui ? ('manquee' as const) : ('prevue' as const);
}

const CHIP_STYLES = {
  faite: 'border-l-2 border-emerald-400 bg-emerald-500/15',
  manquee: 'border-l-2 border-red-400 bg-red-500/15',
  prevue: 'border-l-2 border-neutral-200 bg-neutral-50 dark:border-transparent dark:bg-navy-800/60',
} as const;

/** Payload transporté pendant un drag (magasin du portefeuille ou visite existante). */
type DragData =
  | { type: 'client'; clientId: string }
  | { type: 'planning'; id: string; fait: boolean };

export function PlanningBoard({
  promoteurId,
  days,
  plannings,
  portefeuille,
}: {
  promoteurId: string;
  days: Day[];
  plannings: PlanningItem[];
  portefeuille: ClientRow[];
}) {
  const [query, setQuery] = useState('');
  const [hoverDay, setHoverDay] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const relancer = (v: PlanningItem) => {
    setError(null);
    setInfo(null);
    startTransition(async () => {
      const res = await relancerVisite(v.id);
      if (res.error) setError(res.error);
      else setInfo(`Relance envoyée au promoteur pour ${v.client.enseigne.trim()}.`);
    });
  };

  // Visites par jour (clé = yyyy-mm-dd local).
  const parJour = useMemo(() => {
    const map = new Map<string, PlanningItem[]>();
    for (const d of days) map.set(d.date, []);
    for (const p of plannings) {
      const d = new Date(p.datePassage);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      map.get(key)?.push(p);
    }
    return map;
  }, [days, plannings]);

  // Magasins déjà planifiés cette semaine (pour les griser dans le portefeuille).
  const dejaPlanifies = useMemo(() => new Set(plannings.map((p) => p.client.id)), [plannings]);

  const magasins = useMemo(() => {
    const q = query.trim().toLowerCase();
    const base = q
      ? portefeuille.filter(
          (c) =>
            c.enseigne.toLowerCase().includes(q) || (c.ville ?? '').toLowerCase().includes(q),
        )
      : portefeuille;
    return [...base].sort((a, b) => a.enseigne.localeCompare(b.enseigne));
  }, [portefeuille, query]);

  const onDrop = (dayDate: string, e: React.DragEvent) => {
    e.preventDefault();
    setHoverDay(null);
    let data: DragData;
    try {
      data = JSON.parse(e.dataTransfer.getData('application/json')) as DragData;
    } catch {
      return;
    }
    setError(null);
    startTransition(async () => {
      const res =
        data.type === 'client'
          ? await dropPlanning(promoteurId, data.clientId, dayDate)
          : await movePlanning(data.id, dayDate);
      if (res.error) setError(res.error);
    });
  };

  const aujourdhui = todayIso();

  return (
    <div className="flex flex-col gap-3">
      {/* Légende du code couleur */}
      <div className="flex flex-wrap items-center gap-4 text-xs text-neutral-500">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm bg-emerald-400" />
          Effectuée
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm bg-red-400" />
          Manquée (passée, non faite)
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm bg-neutral-400" />
          À venir
        </span>
      </div>

      {error ? (
        <p className="flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
          <button type="button" onClick={() => setError(null)} className="ml-auto" aria-label="Fermer">
            <X size={14} />
          </button>
        </p>
      ) : null}
      {info ? (
        <p className="flex items-center gap-2 rounded-lg border border-emerald-300 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          <BellRing size={14} />
          {info}
          <button type="button" onClick={() => setInfo(null)} className="ml-auto" aria-label="Fermer">
            <X size={14} />
          </button>
        </p>
      ) : null}

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_280px]">
        {/* Grille de la semaine (zones de dépôt) */}
        <div className={`grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3 ${pending ? 'opacity-60' : ''}`}>
          {days.map((day) => {
            const visites = parJour.get(day.date) ?? [];
            const isHover = hoverDay === day.date;
            const estAujourdhui = day.date === aujourdhui;
            return (
              <section
                key={day.date}
                onDragOver={(e) => {
                  e.preventDefault();
                  setHoverDay(day.date);
                }}
                onDragLeave={() => setHoverDay((h) => (h === day.date ? null : h))}
                onDrop={(e) => onDrop(day.date, e)}
                className={`flex min-h-36 flex-col rounded-2xl border bg-white shadow-card transition ${
                  isHover
                    ? 'border-brand ring-2 ring-brand/30 dark:border-accent dark:ring-accent/40'
                    : 'border-transparent'
                }`}
              >
                <h2 className="flex items-baseline justify-between border-b border-neutral-100 px-3 py-2 dark:border-navy-700">
                  <span className={`text-sm font-semibold ${estAujourdhui ? 'text-brand dark:text-accent' : ''}`}>
                    {day.nom}
                    {estAujourdhui ? ' · auj.' : ''}
                  </span>
                  <span className="text-xs text-neutral-400">{day.label}</span>
                </h2>
                <div className="flex flex-1 flex-col gap-1.5 p-2.5">
                  {visites.map((v) => {
                    const statut = statutVisite(v, aujourdhui);
                    return (
                    <div
                      key={v.id}
                      draggable={!v.fait}
                      onDragStart={(e) => {
                        e.dataTransfer.setData(
                          'application/json',
                          JSON.stringify({ type: 'planning', id: v.id, fait: v.fait } satisfies DragData),
                        );
                        e.dataTransfer.effectAllowed = 'move';
                      }}
                      className={`group flex items-center gap-1.5 rounded-lg px-2 py-1.5 ${CHIP_STYLES[statut]} ${
                        v.fait ? '' : 'cursor-grab active:cursor-grabbing'
                      }`}
                    >
                      {statut === 'faite' ? (
                        <CheckCircle2 size={13} className="shrink-0 text-emerald-400" />
                      ) : statut === 'manquee' ? (
                        <AlertCircle size={13} className="shrink-0 text-red-400" aria-label="Visite manquée" />
                      ) : (
                        <GripVertical size={12} className="shrink-0 text-neutral-500" />
                      )}
                      <ClassBadge value={v.client.niveauClass} size="xs" />
                      <div className="min-w-0 flex-1">
                        <p className="flex items-center gap-1 truncate text-xs font-medium">
                          {v.client.enseigne}
                          {v.plannificationId ? (
                            <Repeat size={10} className="shrink-0 text-[#A78BDA]" aria-label="Visite récurrente" />
                          ) : null}
                        </p>
                        {v.client.ville ? (
                          <p className="truncate text-[10px] text-neutral-400">{v.client.ville}</p>
                        ) : null}
                      </div>
                      {statut === 'manquee' ? (
                        <button
                          type="button"
                          onClick={() => relancer(v)}
                          disabled={pending}
                          className="inline-flex shrink-0 items-center gap-1 rounded-md bg-accent px-1.5 py-1 text-[10px] font-semibold text-brand transition hover:bg-accent/80 disabled:opacity-50"
                          aria-label={`Relancer le promoteur pour ${v.client.enseigne}`}
                          title="Envoyer une notification de relance au promoteur"
                        >
                          <BellRing size={11} />
                          Relancer
                        </button>
                      ) : null}
                      {!v.fait ? (
                        <form action={removePlanning}>
                          <input type="hidden" name="id" value={v.id} />
                          <button
                            type="submit"
                            className="rounded p-0.5 text-neutral-500 opacity-0 transition hover:text-red-400 group-hover:opacity-100"
                            aria-label={`Retirer ${v.client.enseigne}`}
                          >
                            <Trash2 size={12} />
                          </button>
                        </form>
                      ) : null}
                    </div>
                    );
                  })}
                  {visites.length === 0 ? (
                    <p className={`rounded-lg border border-dashed py-2 text-center text-[10px] transition ${
                      isHover ? 'border-accent text-accent' : 'border-navy-600 text-neutral-500'
                    }`}>
                      Déposer un magasin ici
                    </p>
                  ) : null}
                  <AddVisit promoteurId={promoteurId} date={day.date} clients={portefeuille} />
                </div>
              </section>
            );
          })}
        </div>

        {/* Portefeuille du promoteur (source du drag) */}
        <aside className="flex max-h-[70vh] flex-col rounded-2xl bg-white shadow-card xl:sticky xl:top-6">
          <h2 className="flex items-center gap-2 border-b border-neutral-100 px-3 py-2.5 text-sm font-semibold dark:border-navy-700">
            <Store size={15} className="text-[#A78BDA]" />
            Portefeuille
            <span className="ml-auto rounded-full bg-brand/10 px-2 py-0.5 text-xs font-semibold text-brand dark:bg-accent/10 dark:text-accent">
              {magasins.length}
            </span>
          </h2>
          <div className="flex items-center gap-1.5 border-b border-neutral-100 px-3 py-2 dark:border-navy-700">
            <Search size={12} className="shrink-0 text-neutral-500" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Filtrer les magasins…"
              className="w-full bg-transparent text-xs outline-none placeholder:text-neutral-500"
            />
          </div>
          <ul className="flex-1 overflow-y-auto p-1.5">
            {magasins.map((c) => {
              const planifie = dejaPlanifies.has(c.id);
              return (
                <li key={c.id}>
                  <div
                    draggable
                    onDragStart={(e) => {
                      e.dataTransfer.setData(
                        'application/json',
                        JSON.stringify({ type: 'client', clientId: c.id } satisfies DragData),
                      );
                      e.dataTransfer.effectAllowed = 'copy';
                    }}
                    className={`flex cursor-grab items-center gap-1.5 rounded-lg px-2 py-1.5 transition hover:bg-accent/15 active:cursor-grabbing ${
                      planifie ? 'opacity-45' : ''
                    }`}
                    title={planifie ? 'Déjà planifié cette semaine (re-déposable un autre jour)' : 'Glisser vers un jour'}
                  >
                    <GripVertical size={12} className="shrink-0 text-neutral-500" />
                    <ClassBadge value={c.niveauClass} size="xs" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-xs font-medium">{c.enseigne}</p>
                      {c.ville ? (
                        <p className="truncate text-[10px] text-neutral-400">{c.ville}</p>
                      ) : null}
                    </div>
                    {planifie ? <CheckCircle2 size={12} className="shrink-0 text-emerald-400/70" /> : null}
                  </div>
                </li>
              );
            })}
            {magasins.length === 0 ? (
              <li className="px-2 py-3 text-center text-xs text-neutral-400">Aucun magasin.</li>
            ) : null}
          </ul>
        </aside>
      </div>
    </div>
  );
}
