'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import { Megaphone, Plus, Search, Sparkles, Star, Trash2, X } from 'lucide-react';
import {
  addPem,
  addPromo,
  deletePem,
  deletePromo,
  searchArticles,
  togglePromo,
  type PromoState,
} from '@/lib/admin-actions';
import type { ArticleRow, PemRow, PromoRow } from '@/lib/api';

const input =
  'rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';

const INITIAL: PromoState = { error: null, ok: false };

/** Sélecteur d'article : recherche live (server action) + choix, expose `articleId` en hidden. */
function ArticlePicker({ resetKey }: { resetKey: number }) {
  const [term, setTerm] = useState('');
  const [results, setResults] = useState<ArticleRow[]>([]);
  const [chosen, setChosen] = useState<ArticleRow | null>(null);
  const [open, setOpen] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Réinitialise après une soumission réussie (resetKey change).
  useEffect(() => {
    setChosen(null);
    setTerm('');
    setResults([]);
  }, [resetKey]);

  useEffect(() => {
    if (chosen || term.trim().length < 2) {
      setResults([]);
      return;
    }
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(async () => {
      setResults(await searchArticles(term));
      setOpen(true);
    }, 250);
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [term, chosen]);

  if (chosen) {
    return (
      <div className="flex min-w-72 flex-1 items-center gap-2">
        <input type="hidden" name="articleId" value={chosen.id} />
        <div className="flex flex-1 items-center gap-2 rounded-lg border border-brand/40 bg-brand/5 px-2.5 py-1.5 text-sm dark:border-accent/40 dark:bg-accent/10">
          <span className="font-medium">{chosen.libelle}</span>
          <span className="text-xs text-neutral-400">{chosen.codeAs400}</span>
        </div>
        <button
          type="button"
          onClick={() => setChosen(null)}
          className="rounded-lg p-1.5 text-neutral-400 hover:bg-neutral-100 dark:hover:bg-navy-800"
          aria-label="Changer d'article"
        >
          <X size={14} />
        </button>
      </div>
    );
  }

  return (
    <div className="relative min-w-72 flex-1">
      <div className="flex items-center gap-1.5">
        <Search size={14} className="text-neutral-400" />
        <input
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          onFocus={() => setOpen(true)}
          placeholder="Chercher un article (libellé ou code)…"
          className={`${input} w-full`}
        />
      </div>
      {open && results.length > 0 ? (
        <ul className="absolute z-10 mt-1 max-h-64 w-full overflow-auto rounded-lg border border-neutral-200 bg-white shadow-lg dark:border-navy-700 dark:bg-navy-950">
          {results.map((a) => (
            <li key={a.id}>
              <button
                type="button"
                onClick={() => {
                  setChosen(a);
                  setOpen(false);
                }}
                className="flex w-full items-center justify-between gap-2 px-3 py-2 text-left text-sm hover:bg-neutral-50 dark:hover:bg-navy-800"
              >
                <span className="min-w-0 truncate">{a.libelle}</span>
                <span className="shrink-0 text-xs text-neutral-400">{a.codeAs400}</span>
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function AddPromoForm() {
  const [state, action, pending] = useActionState(addPromo, INITIAL);
  const [resetKey, setResetKey] = useState(0);
  useEffect(() => {
    if (state.ok) setResetKey((k) => k + 1);
  }, [state.ok]);

  return (
    <form
      action={action}
      className="flex flex-wrap items-end gap-2 rounded-2xl bg-white p-4 shadow-card"
    >
      <ArticlePicker resetKey={resetKey} />
      <input name="libelle" maxLength={200} placeholder="Libellé (ex : -20%)" className={input} />
      <label className="flex flex-col gap-0.5 text-xs text-neutral-400">
        Début
        <input type="date" name="dateDebut" className={input} />
      </label>
      <label className="flex flex-col gap-0.5 text-xs text-neutral-400">
        Fin
        <input type="date" name="dateFin" className={input} />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Plus size={14} />
        {pending ? 'Ajout…' : 'Créer la promo'}
      </button>
      {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
    </form>
  );
}

function AddPemForm() {
  const [state, action, pending] = useActionState(addPem, INITIAL);
  const [resetKey, setResetKey] = useState(0);
  useEffect(() => {
    if (state.ok) setResetKey((k) => k + 1);
  }, [state.ok]);

  return (
    <form
      action={action}
      className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card"
    >
      <ArticlePicker resetKey={resetKey} />
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Star size={14} />
        {pending ? 'Ajout…' : 'Mettre en avant'}
      </button>
      {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
    </form>
  );
}

function dateFr(iso: string | null): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}

export function PromosEditor({ promos, pem }: { promos: PromoRow[]; pem: PemRow[] }) {
  return (
    <div className="flex flex-col gap-8">
      {/* Promotions */}
      <section className="flex flex-col gap-4">
        <div className="flex items-center gap-2">
          <Megaphone size={18} className="text-brand dark:text-accent" />
          <h2 className="text-lg font-semibold">Promotions</h2>
        </div>
        <AddPromoForm />
        <div className="rounded-2xl bg-white shadow-card">
          {promos.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-neutral-400">
              Aucune promo — ajoute la première ci-dessus. Elle apparaîtra en badge sur l&apos;app
              mobile lors de la prise de commande.
            </p>
          ) : (
            <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
              {promos.map((p) => (
                <li
                  key={p.id}
                  className={`group flex items-center gap-3 px-4 py-3 ${p.actif ? '' : 'opacity-50'}`}
                >
                  <Sparkles size={16} className="shrink-0 text-brand dark:text-accent" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">
                      {p.article.libelle}
                      {p.libelle ? <span className="ml-2 text-brand dark:text-accent">{p.libelle}</span> : null}
                    </p>
                    <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-400">
                      <span>{p.article.codeAs400}</span>
                      {p.dateDebut || p.dateFin ? (
                        <span>
                          {dateFr(p.dateDebut) || '…'} → {dateFr(p.dateFin) || '…'}
                        </span>
                      ) : (
                        <span>sans limite de date</span>
                      )}
                      {!p.actif ? (
                        <span className="rounded-full bg-neutral-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-neutral-400">
                          désactivée
                        </span>
                      ) : null}
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-1 opacity-0 transition group-hover:opacity-100">
                    <form action={togglePromo}>
                      <input type="hidden" name="id" value={p.id} />
                      <input type="hidden" name="actif" value={p.actif ? 'false' : 'true'} />
                      <button
                        type="submit"
                        className="rounded-lg px-2 py-1 text-xs text-neutral-400 transition hover:bg-neutral-100 hover:text-brand dark:hover:bg-navy-800"
                      >
                        {p.actif ? 'Désactiver' : 'Activer'}
                      </button>
                    </form>
                    <form
                      action={deletePromo}
                      onSubmit={(e) => {
                        if (!confirm(`Supprimer la promo sur « ${p.article.libelle} » ?`)) e.preventDefault();
                      }}
                    >
                      <input type="hidden" name="id" value={p.id} />
                      <button
                        type="submit"
                        className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40"
                        aria-label="Supprimer"
                      >
                        <Trash2 size={14} />
                      </button>
                    </form>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      {/* Mises en avant PEM */}
      <section className="flex flex-col gap-4">
        <div className="flex items-center gap-2">
          <Star size={18} className="text-brand dark:text-accent" />
          <h2 className="text-lg font-semibold">Mises en avant (PEM)</h2>
        </div>
        <AddPemForm />
        <div className="rounded-2xl bg-white shadow-card">
          {pem.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-neutral-400">
              Aucun article mis en avant.
            </p>
          ) : (
            <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
              {pem.map((m) => (
                <li
                  key={m.id}
                  className={`group flex items-center gap-3 px-4 py-3 ${m.actif ? '' : 'opacity-50'}`}
                >
                  <Star size={16} className="shrink-0 text-amber-500" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{m.article.libelle}</p>
                    <p className="mt-0.5 text-xs text-neutral-400">{m.article.codeAs400}</p>
                  </div>
                  <form
                    action={deletePem}
                    onSubmit={(e) => {
                      if (!confirm(`Retirer « ${m.article.libelle} » des mises en avant ?`)) e.preventDefault();
                    }}
                    className="shrink-0 opacity-0 transition group-hover:opacity-100"
                  >
                    <input type="hidden" name="id" value={m.id} />
                    <button
                      type="submit"
                      className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40"
                      aria-label="Retirer"
                    >
                      <Trash2 size={14} />
                    </button>
                  </form>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </div>
  );
}
