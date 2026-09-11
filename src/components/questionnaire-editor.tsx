'use client';

import { useActionState, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  CheckSquare,
  Hash,
  Pencil,
  Plus,
  Star,
  Trash2,
  Type,
  X,
} from 'lucide-react';
import {
  addQuestion,
  updateQuestion,
  deplacerQuestion,
  deleteQuestion,
  type QuestionState,
} from '@/lib/admin-actions';
import type { QuestionVisite, TypeQuestion } from '@/lib/api';

const TYPES: { value: TypeQuestion; label: string; icon: typeof CheckSquare }[] = [
  { value: 'CASE_A_COCHER', label: 'Case à cocher', icon: CheckSquare },
  { value: 'TEXTE', label: 'Texte libre', icon: Type },
  { value: 'NOMBRE', label: 'Nombre', icon: Hash },
  { value: 'NOTE_1_5', label: 'Note 1 à 5', icon: Star },
];

const input =
  'rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';

const INITIAL: QuestionState = { error: null, ok: false };

function AddForm() {
  const [state, action, pending] = useActionState(addQuestion, INITIAL);

  return (
    <form
      action={action}
      className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card"
    >
      <input
        name="libelle"
        required
        maxLength={300}
        placeholder="Nouvelle question… (ex : La PLV de la promo en cours est-elle posée ?)"
        className={`${input} min-w-72 flex-1`}
      />
      <select name="type" defaultValue="CASE_A_COCHER" className={input}>
        {TYPES.map((t) => (
          <option key={t.value} value={t.value}>
            {t.label}
          </option>
        ))}
      </select>
      <label className="inline-flex items-center gap-1.5 text-sm text-neutral-500">
        <input type="checkbox" name="obligatoire" className="accent-brand" />
        Obligatoire
      </label>
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Plus size={14} />
        {pending ? 'Ajout…' : 'Ajouter'}
      </button>
      {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
    </form>
  );
}

function EditRow({ q, onClose }: { q: QuestionVisite; onClose: () => void }) {
  return (
    <form
      action={async (fd) => {
        await updateQuestion(fd);
        onClose();
      }}
      className="flex flex-wrap items-center gap-2 px-4 py-3"
    >
      <input type="hidden" name="id" value={q.id} />
      <input name="libelle" defaultValue={q.libelle} required maxLength={300} className={`${input} min-w-64 flex-1`} />
      <select name="type" defaultValue={q.type} className={input}>
        {TYPES.map((t) => (
          <option key={t.value} value={t.value}>
            {t.label}
          </option>
        ))}
      </select>
      <label className="inline-flex items-center gap-1.5 text-xs text-neutral-500">
        <input
          type="checkbox"
          defaultChecked={q.obligatoire}
          onChange={(e) => {
            const hidden = e.currentTarget.form?.elements.namedItem('obligatoire') as HTMLInputElement | null;
            if (hidden) hidden.value = e.currentTarget.checked ? 'true' : 'false';
          }}
          className="accent-brand"
        />
        <input type="hidden" name="obligatoire" defaultValue={q.obligatoire ? 'true' : 'false'} />
        Obligatoire
      </label>
      <button
        type="submit"
        className="rounded-xl bg-brand px-3 py-1.5 text-xs font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand"
      >
        Enregistrer
      </button>
      <button type="button" onClick={onClose} className="rounded-lg p-1.5 text-neutral-400 hover:bg-neutral-100 dark:hover:bg-navy-800" aria-label="Annuler">
        <X size={14} />
      </button>
    </form>
  );
}

export function QuestionnaireEditor({ questions }: { questions: QuestionVisite[] }) {
  const [editing, setEditing] = useState<string | null>(null);

  return (
    <div className="flex flex-col gap-4">
      <AddForm />

      <div className="rounded-2xl bg-white shadow-card">
        {questions.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-neutral-400">
            Aucune question — ajoute la première ci-dessus. L&apos;app mobile affichera ce
            questionnaire à la fin de chaque visite.
          </p>
        ) : (
          <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
            {questions.map((q, i) => {
              const type = TYPES.find((t) => t.value === q.type) ?? TYPES[0];
              const Icon = type.icon;
              return (
                <li key={q.id} className={q.actif ? '' : 'opacity-50'}>
                  {editing === q.id ? (
                    <EditRow q={q} onClose={() => setEditing(null)} />
                  ) : (
                    <div className="group flex items-center gap-3 px-4 py-3">
                      {/* Réordonnancement */}
                      <div className="flex flex-col">
                        <form action={deplacerQuestion}>
                          <input type="hidden" name="id" value={q.id} />
                          <input type="hidden" name="direction" value="haut" />
                          <button
                            type="submit"
                            disabled={i === 0}
                            className="rounded p-0.5 text-neutral-400 transition hover:text-brand disabled:opacity-20"
                            aria-label="Monter"
                          >
                            <ArrowUp size={13} />
                          </button>
                        </form>
                        <form action={deplacerQuestion}>
                          <input type="hidden" name="id" value={q.id} />
                          <input type="hidden" name="direction" value="bas" />
                          <button
                            type="submit"
                            disabled={i === questions.length - 1}
                            className="rounded p-0.5 text-neutral-400 transition hover:text-brand disabled:opacity-20"
                            aria-label="Descendre"
                          >
                            <ArrowDown size={13} />
                          </button>
                        </form>
                      </div>

                      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-semibold text-neutral-500 dark:bg-navy-800 dark:text-white">
                        {i + 1}
                      </span>

                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium">{q.libelle}</p>
                        <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-400">
                          <span className="inline-flex items-center gap-1">
                            <Icon size={11} /> {type.label}
                          </span>
                          {q.obligatoire ? (
                            <span className="rounded-full bg-amber-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-amber-500">
                              obligatoire
                            </span>
                          ) : null}
                          {!q.actif ? (
                            <span className="rounded-full bg-neutral-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-neutral-400">
                              désactivée
                            </span>
                          ) : null}
                          {q._count.reponses > 0 ? (
                            <span>{q._count.reponses} réponse{q._count.reponses > 1 ? 's' : ''}</span>
                          ) : null}
                        </p>
                      </div>

                      {/* Actions */}
                      <div className="flex shrink-0 items-center gap-1 opacity-0 transition group-hover:opacity-100">
                        <button
                          type="button"
                          onClick={() => setEditing(q.id)}
                          className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-brand dark:hover:bg-navy-800"
                          aria-label="Modifier"
                        >
                          <Pencil size={14} />
                        </button>
                        <form action={updateQuestion}>
                          <input type="hidden" name="id" value={q.id} />
                          <input type="hidden" name="actif" value={q.actif ? 'false' : 'true'} />
                          <button
                            type="submit"
                            className="rounded-lg px-2 py-1 text-xs text-neutral-400 transition hover:bg-neutral-100 hover:text-brand dark:hover:bg-navy-800"
                          >
                            {q.actif ? 'Désactiver' : 'Activer'}
                          </button>
                        </form>
                        <form
                          action={deleteQuestion}
                          onSubmit={(e) => {
                            if (!confirm(`Supprimer la question « ${q.libelle} » ?`)) e.preventDefault();
                          }}
                        >
                          <input type="hidden" name="id" value={q.id} />
                          <button
                            type="submit"
                            className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40"
                            aria-label="Supprimer"
                          >
                            <Trash2 size={14} />
                          </button>
                        </form>
                      </div>
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}
