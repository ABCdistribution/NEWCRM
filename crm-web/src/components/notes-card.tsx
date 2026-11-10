'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { StickyNote, Plus, Trash2, X } from 'lucide-react';
import { addNote, deleteNote, type NoteFormState } from '@/lib/client-actions';
import { SuppressionForm } from './suppression-form';

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
        aria-label="Note terrain"
        className="w-full resize-y rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
      />

      {state.error ? <p role="alert" className="text-xs text-red-700">{state.error}</p> : null}

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

/**
 * Notes terrain du magasin. `peutEditer` (rôles de EDITEURS_CLIENT, calculé par la page) masque les boutons
 * d'ajout et de suppression ; l'API et les Server Actions restent juges.
 */
export function NotesCard({
  clientId,
  notes,
  peutEditer,
}: {
  clientId: string;
  notes: NoteItem[];
  peutEditer: boolean;
}) {
  const [adding, setAdding] = useState(false);

  return (
    <div className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
        <StickyNote size={17} className="text-brand" />
        Notes terrain
        <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
          {notes.length}
        </span>
        {peutEditer ? (
          <button
            type="button"
            onClick={() => setAdding((v) => !v)}
            className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand dark:border-navy-700 dark:text-neutral-300 dark:focus-visible:outline-accent"
          >
            {adding ? <X size={13} /> : <Plus size={13} />}
            {adding ? 'Fermer' : 'Ajouter'}
          </button>
        ) : null}
      </h2>

      {peutEditer && adding ? <NoteForm clientId={clientId} onClose={() => setAdding(false)} /> : null}

      {notes.length === 0 && !(peutEditer && adding) ? (
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
              {/* Action révélée au survol ou au focus ; toujours visible sur écran tactile. */}
              {peutEditer ? (
                <div className="shrink-0 opacity-0 transition group-hover:opacity-100 focus-within:opacity-100 [@media(hover:none)]:opacity-100">
                  <SuppressionForm
                    action={deleteNote}
                    champs={{ clientId, noteId: n.id }}
                    confirmation="Supprimer cette note ?"
                    libelle="Supprimer la note"
                  />
                </div>
              ) : null}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
