'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { StickyNote, Plus, Trash2, X } from 'lucide-react';
import { addNote, deleteNote, type NoteFormState } from '@/lib/client-actions';

export type NoteItem = {
  id: string;
  remarque: string;
  createdAt: string;
  auteur: { displayName: string } | null;
};

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });

const INITIAL: NoteFormState = { error: null, ok: false };

function NoteForm({ clientId, onClose }: { clientId: string; onClose: () => void }) {
  const [state, action, pending] = useActionState(addNote, INITIAL);
  const ref = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    ref.current?.focus();
  }, []);

  // Ferme le formulaire une fois l'enregistrement confirmé.
  useEffect(() => {
    if (state.ok) onClose();
  }, [state.ok, onClose]);

  return (
    <form
      action={action}
      className="flex flex-col gap-2.5 border-t border-neutral-100 bg-neutral-50/60 px-5 py-4 dark:border-navy-700 dark:bg-navy-950/40"
    >
      <input type="hidden" name="clientId" value={clientId} />
      <textarea
        ref={ref}
        name="remarque"
        rows={3}
        required
        maxLength={2000}
        placeholder="Note terrain : rayon, PLV, concurrence, à prévoir…"
        className="w-full resize-y rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
      />

      {state.error ? <p className="text-xs text-red-600">{state.error}</p> : null}

      <div className="flex justify-end gap-2 pt-1">
        <button
          type="button"
          onClick={onClose}
          className="rounded-lg px-3 py-1.5 text-xs text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
        >
          Annuler
        </button>
        <button
          type="submit"
          disabled={pending}
          className="rounded-xl bg-brand px-3 py-1.5 text-xs font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80 disabled:opacity-50"
        >
          {pending ? 'Enregistrement…' : 'Ajouter la note'}
        </button>
      </div>
    </form>
  );
}

export function NotesCard({ clientId, notes }: { clientId: string; notes: NoteItem[] }) {
  const [adding, setAdding] = useState(false);

  return (
    <div className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
        <StickyNote size={17} className="text-brand" />
        Notes terrain
        <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
          {notes.length}
        </span>
        <button
          type="button"
          onClick={() => setAdding((v) => !v)}
          className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300"
        >
          {adding ? <X size={13} /> : <Plus size={13} />}
          {adding ? 'Fermer' : 'Ajouter'}
        </button>
      </h2>

      {adding ? <NoteForm clientId={clientId} onClose={() => setAdding(false)} /> : null}

      {notes.length === 0 && !adding ? (
        <p className="px-5 py-4 text-sm text-neutral-400">Aucune note.</p>
      ) : (
        <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
          {notes.map((n) => (
            <li key={n.id} className="group flex items-start gap-2 px-5 py-3">
              <div className="min-w-0 flex-1">
                <p className="whitespace-pre-wrap text-sm">{n.remarque}</p>
                <p className="mt-1 text-xs text-neutral-400">
                  {n.auteur?.displayName ?? 'Inconnu'} · {DATE_FMT.format(new Date(n.createdAt))}
                </p>
              </div>
              <form
                action={deleteNote}
                className="shrink-0 opacity-0 transition group-hover:opacity-100"
                onSubmit={(e) => {
                  if (!confirm('Supprimer cette note ?')) e.preventDefault();
                }}
              >
                <input type="hidden" name="clientId" value={clientId} />
                <input type="hidden" name="noteId" value={n.id} />
                <button
                  type="submit"
                  className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/40"
                  aria-label="Supprimer la note"
                >
                  <Trash2 size={14} />
                </button>
              </form>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
