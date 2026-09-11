'use client';

import { useActionState, useEffect, useMemo, useRef, useState } from 'react';
import { Plus, Search } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { addPlanning, type PlanningState } from '@/lib/planning-actions';

const INITIAL: PlanningState = { error: null, ok: false };

type ClientOption = { id: string; enseigne: string; ville: string | null; niveauClass: string | null };

/**
 * Ajout d'une visite dans une case jour : recherche du magasin dans le
 * portefeuille du promoteur (combobox), clic ou Entrée pour planifier.
 */
export function AddVisit({
  promoteurId,
  date,
  clients,
}: {
  promoteurId: string;
  date: string; // yyyy-mm-dd
  clients: ClientOption[];
}) {
  const [state, action, pending] = useActionState(addPlanning, INITIAL);
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const clientIdRef = useRef<HTMLInputElement>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  // Reset après un ajout réussi.
  useEffect(() => {
    if (state.ok) {
      setQuery('');
      setOpen(false);
    }
  }, [state.ok]);

  // Ferme la liste au clic en dehors.
  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  const matches = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return clients.slice(0, 8);
    return clients
      .filter(
        (c) =>
          c.enseigne.toLowerCase().includes(q) || (c.ville ?? '').toLowerCase().includes(q),
      )
      .slice(0, 8);
  }, [clients, query]);

  const pick = (c: ClientOption) => {
    if (!clientIdRef.current || !formRef.current) return;
    clientIdRef.current.value = c.id;
    formRef.current.requestSubmit();
  };

  return (
    <div ref={boxRef} className="relative mt-1">
      <form ref={formRef} action={action}>
        <input type="hidden" name="promoteurId" value={promoteurId} />
        <input type="hidden" name="datePassage" value={date} />
        <input ref={clientIdRef} type="hidden" name="clientId" defaultValue="" />

        <div className="flex items-center gap-1 rounded-md border border-dashed border-neutral-300 px-1.5 dark:border-navy-600">
          <Search size={11} className="shrink-0 text-neutral-500" />
          <input
            type="text"
            value={query}
            disabled={pending}
            placeholder="+ magasin…"
            onChange={(e) => {
              setQuery(e.target.value);
              setOpen(true);
            }}
            onFocus={() => setOpen(true)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                if (matches[0]) pick(matches[0]);
              } else if (e.key === 'Escape') {
                setOpen(false);
              }
            }}
            className="w-full min-w-0 bg-transparent py-1 text-[11px] text-neutral-300 outline-none placeholder:text-neutral-500 disabled:opacity-50"
          />
          {pending ? <Plus size={12} className="shrink-0 animate-spin text-brand dark:text-accent" /> : null}
        </div>
      </form>

      {/* Liste des résultats */}
      {open && !pending ? (
        <ul className="absolute left-0 top-full z-30 mt-1 max-h-56 w-64 overflow-y-auto rounded-lg border border-navy-600 bg-navy-900 p-1 shadow-xl">
          {matches.length === 0 ? (
            <li className="px-2 py-1.5 text-[11px] text-neutral-400">Aucun magasin trouvé.</li>
          ) : (
            matches.map((c) => (
              <li key={c.id}>
                <button
                  type="button"
                  onClick={() => pick(c)}
                  className="flex w-full items-baseline gap-1.5 rounded-md px-2 py-1.5 text-left transition hover:bg-accent/20"
                >
                  <ClassBadge value={c.niveauClass} size="xs" />
                  <span className="min-w-0 flex-1 truncate text-[11px] font-medium text-neutral-100">
                    {c.enseigne}
                  </span>
                  {c.ville ? (
                    <span className="shrink-0 text-[10px] text-neutral-400">{c.ville}</span>
                  ) : null}
                </button>
              </li>
            ))
          )}
        </ul>
      ) : null}

      {state.error ? <p className="mt-0.5 text-[10px] text-red-400">{state.error}</p> : null}
    </div>
  );
}
