'use client';

import { useActionState, useEffect, useMemo, useState } from 'react';
import { Plus, Repeat, Search, Trash2, X } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { addRegle, removeRegle, type RegleState } from '@/lib/planning-actions';
import type { RegleRecurrence, ClientRow } from '@/lib/api';

const INITIAL: RegleState = { error: null, ok: false };
const JOURS_COURTS = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const FREQUENCES = [
  { value: 1, label: 'Chaque semaine' },
  { value: 2, label: 'Toutes les 2 sem.' },
  { value: 3, label: 'Toutes les 3 sem.' },
  { value: 4, label: 'Toutes les 4 sem.' },
];

function libelleJours(csv: string): string {
  return csv
    .split(',')
    .map((s) => JOURS_COURTS[Number(s) - 1])
    .filter(Boolean)
    .join(', ');
}

function libelleFrequence(rec: number): string {
  return rec === 1 ? 'chaque sem.' : `ttes les ${rec} sem.`;
}

export function RecurrenceCard({
  promoteurId,
  semaineIso,
  regles,
  portefeuille,
}: {
  promoteurId: string;
  semaineIso: string; // lundi affiché — ancre par défaut des nouvelles règles
  regles: RegleRecurrence[];
  portefeuille: ClientRow[];
}) {
  const [formOpen, setFormOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [clientId, setClientId] = useState('');
  const [state, action, pending] = useActionState(addRegle, INITIAL);

  useEffect(() => {
    if (state.ok) {
      setFormOpen(false);
      setQuery('');
      setClientId('');
    }
  }, [state.ok]);

  const dejaRegle = useMemo(() => new Set(regles.map((r) => r.client.id)), [regles]);
  const matches = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return portefeuille
      .filter(
        (c) =>
          !dejaRegle.has(c.id) &&
          (c.enseigne.toLowerCase().includes(q) || (c.ville ?? '').toLowerCase().includes(q)),
      )
      .slice(0, 6);
  }, [portefeuille, query, dejaRegle]);

  const selection = portefeuille.find((c) => c.id === clientId) ?? null;

  return (
    <section className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-4 py-2.5 text-sm font-semibold dark:border-navy-700">
        <Repeat size={15} className="text-[#A78BDA]" />
        Magasins récurrents
        <span className="rounded-full bg-brand/10 px-2 py-0.5 text-xs font-semibold text-brand dark:bg-accent/10 dark:text-accent">
          {regles.length}
        </span>
        <button
          type="button"
          onClick={() => setFormOpen((o) => !o)}
          className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium transition hover:border-accent hover:text-accent dark:border-navy-700"
        >
          {formOpen ? <X size={12} /> : <Plus size={12} />}
          {formOpen ? 'Fermer' : 'Ajouter'}
        </button>
      </h2>

      {/* Formulaire de nouvelle règle */}
      {formOpen ? (
        <form
          action={action}
          className="flex flex-wrap items-center gap-3 border-b border-neutral-100 bg-navy-950/40 px-4 py-3 dark:border-navy-700"
        >
          <input type="hidden" name="promoteurId" value={promoteurId} />
          <input type="hidden" name="dateDebut" value={semaineIso} />
          <input type="hidden" name="clientId" value={clientId} />

          {/* Choix du magasin (recherche) */}
          <div className="relative min-w-56 flex-1">
            {selection ? (
              <div className="flex items-center gap-1.5 rounded-lg border border-accent/50 px-2 py-1.5">
                <ClassBadge value={selection.niveauClass} size="xs" />
                <span className="min-w-0 flex-1 truncate text-xs font-medium">{selection.enseigne}</span>
                <button
                  type="button"
                  onClick={() => setClientId('')}
                  className="text-neutral-500 hover:text-red-400"
                  aria-label="Changer de magasin"
                >
                  <X size={12} />
                </button>
              </div>
            ) : (
              <>
                <div className="flex items-center gap-1.5 rounded-lg border border-dashed border-navy-600 px-2 py-1.5">
                  <Search size={12} className="shrink-0 text-neutral-500" />
                  <input
                    type="text"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Rechercher le magasin…"
                    className="w-full bg-transparent text-xs outline-none placeholder:text-neutral-500"
                  />
                </div>
                {matches.length > 0 ? (
                  <ul className="absolute left-0 top-full z-30 mt-1 w-72 rounded-lg border border-navy-600 bg-navy-900 p-1 shadow-xl">
                    {matches.map((c) => (
                      <li key={c.id}>
                        <button
                          type="button"
                          onClick={() => {
                            setClientId(c.id);
                            setQuery('');
                          }}
                          className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-left transition hover:bg-accent/20"
                        >
                          <ClassBadge value={c.niveauClass} size="xs" />
                          <span className="min-w-0 flex-1 truncate text-xs font-medium">{c.enseigne}</span>
                          {c.ville ? <span className="shrink-0 text-[10px] text-neutral-400">{c.ville}</span> : null}
                        </button>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </>
            )}
          </div>

          {/* Jours de la semaine */}
          <div className="flex items-center gap-1">
            {JOURS_COURTS.map((jour, idx) => (
              <label
                key={jour}
                className="cursor-pointer select-none rounded-md border border-navy-600 px-1.5 py-1 text-[11px] text-neutral-300 transition has-checked:border-accent has-checked:bg-accent has-checked:font-semibold has-checked:text-brand"
              >
                <input type="checkbox" name="jours" value={idx + 1} className="sr-only" />
                {jour}
              </label>
            ))}
          </div>

          {/* Fréquence */}
          <select
            name="recurrence"
            defaultValue={1}
            className="rounded-lg border border-navy-600 bg-navy-950 px-2 py-1.5 text-xs outline-none focus:border-accent"
          >
            {FREQUENCES.map((f) => (
              <option key={f.value} value={f.value}>
                {f.label}
              </option>
            ))}
          </select>

          <button
            type="submit"
            disabled={pending || !clientId}
            className="rounded-xl bg-accent px-3 py-1.5 text-xs font-semibold text-brand transition hover:bg-accent/80 disabled:opacity-40"
          >
            {pending ? 'Création…' : 'Créer la récurrence'}
          </button>

          {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
        </form>
      ) : null}

      {/* Règles existantes */}
      {regles.length === 0 && !formOpen ? (
        <p className="px-4 py-3 text-xs text-neutral-400">
          Aucun magasin récurrent — les règles créées ici génèrent automatiquement les visites des
          semaines à venir.
        </p>
      ) : regles.length > 0 ? (
        <ul className="flex flex-wrap gap-2 px-4 py-3">
          {regles.map((r) => (
            <li
              key={r.id}
              className="group flex items-center gap-1.5 rounded-full bg-navy-800/60 py-1 pl-2 pr-1"
            >
              <ClassBadge value={r.client.niveauClass} size="xs" />
              <span className="max-w-44 truncate text-xs font-medium">{r.client.enseigne}</span>
              <span className="text-[10px] text-brand dark:text-accent">
                {libelleJours(r.jours)} · {libelleFrequence(r.recurrence)}
              </span>
              <form action={removeRegle}>
                <input type="hidden" name="id" value={r.id} />
                <button
                  type="submit"
                  className="rounded-full p-1 text-neutral-500 transition hover:bg-red-950/50 hover:text-red-400"
                  aria-label={`Supprimer la récurrence ${r.client.enseigne}`}
                  title="Supprimer (retire aussi les visites futures non faites)"
                >
                  <Trash2 size={11} />
                </button>
              </form>
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
}
