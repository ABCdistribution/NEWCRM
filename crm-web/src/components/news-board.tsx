'use client';

import { useActionState, useEffect, useState, useTransition } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Plus, X, Pencil, Trash2, Image as ImageIcon, User, CalendarDays, Eye, EyeOff } from 'lucide-react';
import type { News, NewsPage } from '@/lib/news';
import { saveNews, setNewsPubliee, deleteNews, type NewsFormState } from '@/lib/news-actions';

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
const INITIAL: NewsFormState = { error: null };

const focus = 'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';
const field =
  'w-full rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';
const btnPrimary = `inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-60 dark:bg-accent dark:text-brand dark:hover:bg-accent/80 ${focus}`;
const btnGhost = `inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-1.5 text-sm transition hover:bg-neutral-100 disabled:opacity-60 dark:border-navy-700 dark:hover:bg-navy-800 ${focus}`;

function dateNews(n: News): string {
  return DATE_FMT.format(new Date(n.publieeAt ?? n.createdAt));
}

function Thumb({ src }: { src: string | null }) {
  if (src) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={src} alt="" loading="lazy" referrerPolicy="no-referrer" className="h-11 w-14 shrink-0 rounded-lg border border-neutral-100 object-cover dark:border-navy-700" />;
  }
  return (
    <span className="flex h-11 w-14 shrink-0 items-center justify-center rounded-lg bg-brand/10 text-brand dark:text-accent" aria-hidden>
      <ImageIcon size={18} />
    </span>
  );
}

function Pastille({ publiee }: { publiee: boolean }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${
        publiee ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'
      }`}
    >
      {publiee ? 'Publiée' : 'Brouillon'}
    </span>
  );
}

/** Liste des news (réelles, via l'API) avec détail en feuille et, pour ADMIN / MARKETING, l'administration. */
export function NewsBoard({ data, canManage }: { data: NewsPage; canManage: boolean }) {
  const pathname = usePathname();
  const [detailId, setDetailId] = useState<string | null>(null);
  const [edition, setEdition] = useState<News | 'nouvelle' | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  // Les données viennent du serveur : le détail se retrouve par id (et se ferme si la news disparaît).
  const detail = data.items.find((n) => n.id === detailId) ?? null;
  const pages = Math.max(1, Math.ceil(data.total / data.pageSize));
  const lien = (p: number) => `${pathname}?page=${p}`;

  const basculer = (n: News) => {
    setErreur(null);
    startTransition(async () => {
      const r = await setNewsPubliee(n.id, !n.publiee);
      if (r.error) setErreur(r.error);
    });
  };

  const supprimer = (n: News) => {
    if (!window.confirm(`Supprimer la news « ${n.titre} » ? Cette action est définitive.`)) return;
    setErreur(null);
    startTransition(async () => {
      const r = await deleteNews(n.id);
      if (r.error) setErreur(r.error);
      else setDetailId(null);
    });
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Les News</h1>
        {canManage ? (
          <button type="button" onClick={() => setEdition('nouvelle')} className={btnPrimary}>
            <Plus size={15} aria-hidden /> Nouvelle news
          </button>
        ) : null}
      </div>

      {erreur ? (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{erreur}</p>
      ) : null}

      {data.items.length === 0 ? (
        <p className="rounded-2xl bg-white p-6 text-sm text-neutral-500 shadow-card">Aucune news pour le moment.</p>
      ) : (
        <ul className="divide-y divide-neutral-100 overflow-hidden rounded-2xl bg-white shadow-card dark:divide-navy-700">
          {data.items.map((n) => (
            <li key={n.id}>
              <button
                type="button"
                onClick={() => setDetailId(n.id)}
                className={`flex w-full items-start gap-3 px-4 py-3 text-left transition hover:bg-neutral-50 dark:hover:bg-navy-800 ${focus}`}
              >
                <Thumb src={n.imageUrl} />
                <span className="min-w-0 flex-1">
                  <span className="flex flex-wrap items-center gap-2">
                    <span className="font-semibold">{n.titre}</span>
                    {canManage ? <Pastille publiee={n.publiee} /> : null}
                  </span>
                  <span className="mt-0.5 line-clamp-2 block text-sm text-neutral-500">{n.extrait}</span>
                  <span className="mt-1 flex flex-wrap items-center gap-3 text-xs text-neutral-400">
                    <span className="inline-flex items-center gap-1"><User size={12} aria-hidden />{n.auteur.displayName}</span>
                    <span className="inline-flex items-center gap-1"><CalendarDays size={12} aria-hidden />{dateNews(n)}</span>
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {pages > 1 ? (
        <nav aria-label="Pagination des news" className="flex items-center justify-between text-sm text-neutral-500">
          <span>{data.total} news · page {data.page}/{pages}</span>
          <span className="flex gap-2">
            {data.page > 1 ? <Link href={lien(data.page - 1)} className={btnGhost}>Précédent</Link> : null}
            {data.page < pages ? <Link href={lien(data.page + 1)} className={btnGhost}>Suivant</Link> : null}
          </span>
        </nav>
      ) : null}

      {detail ? (
        <Feuille titre={detail.titre} onClose={() => setDetailId(null)}>
          <div className="flex flex-wrap items-center gap-3 text-xs text-neutral-500">
            <span className="inline-flex items-center gap-1"><User size={12} aria-hidden />{detail.auteur.displayName}</span>
            <span className="inline-flex items-center gap-1"><CalendarDays size={12} aria-hidden />{dateNews(detail)}</span>
            {canManage ? <Pastille publiee={detail.publiee} /> : null}
          </div>
          {detail.imageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={detail.imageUrl} alt={`Illustration : ${detail.titre}`} referrerPolicy="no-referrer" className="mt-3 max-h-72 w-full rounded-xl object-cover" />
          ) : null}
          {/* Texte brut : rendu comme texte (jamais en HTML), retours à la ligne conservés. */}
          <p className="mt-3 whitespace-pre-wrap break-words text-sm leading-relaxed">{detail.contenu}</p>
          {canManage ? (
            <div className="mt-5 flex flex-wrap gap-2 border-t border-neutral-100 pt-3 dark:border-navy-700">
              <button type="button" onClick={() => { setEdition(detail); setDetailId(null); }} className={btnGhost}>
                <Pencil size={14} aria-hidden /> Modifier
              </button>
              <button type="button" disabled={pending} onClick={() => basculer(detail)} className={btnGhost}>
                {detail.publiee ? <EyeOff size={14} aria-hidden /> : <Eye size={14} aria-hidden />}
                {detail.publiee ? 'Dépublier' : 'Publier'}
              </button>
              <button type="button" disabled={pending} onClick={() => supprimer(detail)} className={`${btnGhost} text-red-600`}>
                <Trash2 size={14} aria-hidden /> Supprimer
              </button>
            </div>
          ) : null}
        </Feuille>
      ) : null}

      {edition ? (
        <Formulaire news={edition === 'nouvelle' ? null : edition} onClose={() => setEdition(null)} />
      ) : null}
    </div>
  );
}

/** Fenêtre modale accessible (rôle dialog, Échap, fond cliquable). */
function Feuille({ titre, onClose, children }: { titre: string; onClose: () => void; children: React.ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-4 pt-12 sm:pt-16" role="dialog" aria-modal="true" aria-label={titre}>
      <button type="button" className="fixed inset-0 bg-black/40" aria-label="Fermer" onClick={onClose} tabIndex={-1} />
      <div className="relative w-full max-w-2xl rounded-2xl bg-white p-5 shadow-xl dark:bg-navy-900">
        <div className="mb-3 flex items-start justify-between gap-3">
          <h2 className="text-lg font-bold">{titre}</h2>
          <button type="button" onClick={onClose} className={`rounded-lg p-1 text-neutral-400 hover:text-neutral-600 ${focus}`} aria-label="Fermer">
            <X size={18} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

/** Création / modification d'une news (Server Action `saveNews`). */
function Formulaire({ news, onClose }: { news: News | null; onClose: () => void }) {
  const [state, action, pending] = useActionState(saveNews, INITIAL);

  useEffect(() => {
    if (state.ok) onClose();
  }, [state, onClose]);

  return (
    <Feuille titre={news ? 'Modifier la news' : 'Nouvelle news'} onClose={onClose}>
      <form action={action} className="flex flex-col gap-3">
        {news ? <input type="hidden" name="id" value={news.id} /> : null}
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          Titre
          <input name="titre" required maxLength={200} defaultValue={news?.titre ?? ''} className={field} />
        </label>
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          Contenu (texte brut)
          <textarea name="contenu" required maxLength={20000} rows={8} defaultValue={news?.contenu ?? ''} className={field} />
        </label>
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          Image (adresse https ou chemin commençant par « / », facultatif)
          <input name="imageUrl" maxLength={500} defaultValue={news?.imageUrl ?? ''} placeholder="https://…" className={field} />
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="publiee" defaultChecked={news?.publiee ?? false} className="h-4 w-4 accent-brand" />
          Publiée (visible par tous les utilisateurs)
        </label>
        {state.error ? <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{state.error}</p> : null}
        <div className="flex justify-end gap-2">
          <button type="button" onClick={onClose} className={btnGhost}>Annuler</button>
          <button type="submit" disabled={pending} className={btnPrimary}>
            {pending ? 'Enregistrement…' : 'Enregistrer'}
          </button>
        </div>
      </form>
    </Feuille>
  );
}
