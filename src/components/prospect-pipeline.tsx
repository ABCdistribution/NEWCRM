'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Target, X } from 'lucide-react';
import { setProspectStatut } from '@/lib/prospect-actions';
import type { PipelineColonne, ProspectRow, ProspectStatut } from '@/lib/api';
import { STATUT_LABELS, STATUT_ACCENT } from './prospect-badges';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

export function ProspectPipeline({ colonnes }: { colonnes: PipelineColonne[] }) {
  const router = useRouter();
  const [cols, setCols] = useState<PipelineColonne[]>(colonnes);
  const [hover, setHover] = useState<ProspectStatut | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const totalPondere = cols.reduce((s, c) => s + (c.valeurPonderee ?? 0), 0);

  const move = (prospectId: string, from: ProspectStatut, to: ProspectStatut) => {
    if (from === to) return;
    // Déplacement optimiste : on bouge la carte tout de suite.
    setCols((prev) => {
      let card: ProspectRow | undefined;
      const next = prev.map((c) => {
        if (c.statut === from) {
          card = c.prospects.find((p) => p.id === prospectId);
          return { ...c, prospects: c.prospects.filter((p) => p.id !== prospectId), total: Math.max(0, c.total - 1) };
        }
        return c;
      });
      if (!card) return prev;
      return next.map((c) =>
        c.statut === to ? { ...c, prospects: [card!, ...c.prospects], total: c.total + 1 } : c,
      );
    });
    setError(null);
    startTransition(async () => {
      const res = await setProspectStatut(prospectId, to);
      if (res.error) setError(res.error);
      router.refresh(); // resynchronise totaux + valeur pondérée
    });
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <p className="text-sm text-neutral-500">
          <Target size={14} className="mr-1 inline text-brand dark:text-accent" />
          Valeur pondérée du pipeline&nbsp;:{' '}
          <span className="font-semibold text-brand dark:text-accent">{EUR.format(totalPondere)}</span>
          <span className="text-neutral-400"> (CA potentiel × probabilité)</span>
        </p>
        {pending ? <span className="text-xs text-neutral-400">Enregistrement…</span> : null}
      </div>

      {error ? (
        <p className="flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
          <button type="button" onClick={() => setError(null)} className="ml-auto" aria-label="Fermer">
            <X size={14} />
          </button>
        </p>
      ) : null}

      <div className="flex gap-3 overflow-x-auto pb-2">
        {cols.map((c) => {
          const isHover = hover === c.statut;
          return (
            <section
              key={c.statut}
              onDragOver={(e) => {
                e.preventDefault();
                setHover(c.statut);
              }}
              onDragLeave={() => setHover((h) => (h === c.statut ? null : h))}
              onDrop={(e) => {
                e.preventDefault();
                setHover(null);
                try {
                  const d = JSON.parse(e.dataTransfer.getData('application/json')) as {
                    id: string;
                    statut: ProspectStatut;
                  };
                  move(d.id, d.statut, c.statut);
                } catch {
                  /* ignore */
                }
              }}
              className={`flex w-72 shrink-0 flex-col rounded-2xl bg-white shadow-card transition ${
                isHover ? 'ring-2 ring-brand/40 dark:ring-accent/40' : ''
              }`}
            >
              <header className="flex items-center gap-2 border-b border-neutral-100 px-3 py-2.5 dark:border-navy-700">
                <span className={`h-2.5 w-2.5 rounded-full ${STATUT_ACCENT[c.statut] ?? 'bg-neutral-400'}`} />
                <span className="text-sm font-semibold">{STATUT_LABELS[c.statut] ?? c.statut}</span>
                <span className="ml-auto rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-semibold text-neutral-500 dark:bg-navy-800">
                  {c.total}
                </span>
              </header>
              <div className="border-b border-neutral-100 px-3 py-1.5 text-xs text-neutral-400 dark:border-navy-700">
                {EUR.format(c.valeurPonderee ?? 0)} pondéré
              </div>
              <div className="flex min-h-24 flex-col gap-2 p-2.5">
                {c.prospects.length === 0 ? (
                  <p className={`rounded-lg border border-dashed py-4 text-center text-[10px] transition ${isHover ? 'border-brand text-brand dark:border-accent dark:text-accent' : 'border-neutral-200 text-neutral-300 dark:border-navy-700 dark:text-neutral-600'}`}>
                    Déposer ici
                  </p>
                ) : (
                  c.prospects.map((p) => (
                    <div
                      key={p.id}
                      draggable
                      onDragStart={(e) => {
                        e.dataTransfer.setData('application/json', JSON.stringify({ id: p.id, statut: c.statut }));
                        e.dataTransfer.effectAllowed = 'move';
                      }}
                      className="cursor-grab rounded-lg border border-neutral-100 bg-neutral-50 px-2.5 py-2 active:cursor-grabbing dark:border-navy-700 dark:bg-navy-800/40"
                    >
                      <Link href={`/pilotage/prospects/${p.id}`} className="truncate text-xs font-medium hover:underline">
                        {p.enseigne}
                      </Link>
                      {p.ville ? <p className="truncate text-[10px] text-neutral-400">{p.ville}</p> : null}
                      <div className="mt-1 flex items-center justify-between text-[10px] text-neutral-400">
                        <span>{p.potentielCaAnnuel != null ? EUR.format(p.potentielCaAnnuel) : '—'}</span>
                        <span>{p.probabilite != null ? `${p.probabilite}%` : ''}</span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}
