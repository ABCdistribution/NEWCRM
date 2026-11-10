'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { X } from 'lucide-react';
import { changerEtapeFiche } from '@/lib/prospect-actions';
import { MOTIFS_PERTE, type MotifPerteCode } from '@/lib/prospect-motifs';
import { ClassBadge } from './class-badge';
import type { PipelineColonne, ProspectRow, ProspectStatut } from '@/lib/api';
import { STATUT_LABELS, STATUT_ACCENT } from './prospect-badges';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/**
 * Kanban du pipeline. `lectureSeule` (rôle sans droit d'écriture sur les prospects, ex. DIRECTION) : les cartes
 * ne se déplacent pas, seules les fiches s'ouvrent. Le dépôt dans « Perdu » demande d'abord le motif de la perte
 * (l'API le refuse sinon) : la carte ne bouge qu'une fois le motif choisi.
 */
export function ProspectPipeline({ colonnes, lectureSeule = false }: { colonnes: PipelineColonne[]; lectureSeule?: boolean }) {
  const router = useRouter();
  const [cols, setCols] = useState<PipelineColonne[]>(colonnes);
  const [hover, setHover] = useState<ProspectStatut | null>(null);
  // Dépôt dans « Perdu » en attente du motif de la perte.
  const [attenteMotif, setAttenteMotif] = useState<{ id: string; from: ProspectStatut; enseigne: string } | null>(null);
  // Carte en cours de drag — plus fiable que dataTransfer seul (certains navigateurs
  // le vident quand le drag démarre sur un élément nativement draggable comme un lien).
  const dragRef = useRef<{ id: string; statut: ProspectStatut } | null>(null);

  useEffect(() => {
    setCols(colonnes);
  }, [colonnes]);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const move = (prospectId: string, from: ProspectStatut, to: ProspectStatut, motifPerte?: MotifPerteCode) => {
    if (lectureSeule || from === to) return;
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
      try {
        const res = await changerEtapeFiche(prospectId, to, motifPerte);
        if (res.error) setError(res.error);
      } catch {
        setError("Le déplacement n'a pas pu être enregistré (session expirée ou API injoignable).");
      }
      router.refresh(); // resynchronise les colonnes et les totaux (annule le déplacement en cas d'échec)
    });
  };

  /** Dépôt d'une carte : « Perdu » passe d'abord par le choix du motif, les autres étapes partent tout de suite. */
  const deposer = (d: { id: string; statut: ProspectStatut }, to: ProspectStatut) => {
    if (lectureSeule || d.statut === to) return;
    if (to === 'PERDU') {
      const carte = cols.flatMap((c) => c.prospects).find((p) => p.id === d.id);
      setError(null);
      setAttenteMotif({ id: d.id, from: d.statut, enseigne: carte?.enseigne ?? 'ce prospect' });
      return;
    }
    setAttenteMotif(null);
    move(d.id, d.statut, to);
  };

  return (
    <div className="flex flex-col gap-3">
      {pending ? (
        <span role="status" className="text-xs text-neutral-400">
          Enregistrement…
        </span>
      ) : null}

      {error ? (
        <p role="alert" className="flex items-center gap-2 rounded-lg border border-red-300 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
          <button
            type="button"
            onClick={() => setError(null)}
            className="ml-auto rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
            aria-label="Fermer"
          >
            <X size={14} />
          </button>
        </p>
      ) : null}

      {attenteMotif ? (
        <div role="group" aria-label="Motif de la perte" className="flex flex-wrap items-center gap-1.5 rounded-lg border border-red-200 bg-red-50/60 px-3 py-2 text-xs dark:border-red-900 dark:bg-red-950/20">
          <span className="font-medium text-red-500">Motif de la perte pour « {attenteMotif.enseigne} » :</span>
          {MOTIFS_PERTE.map(([code, label]) => (
            <button
              key={code}
              type="button"
              disabled={pending}
              onClick={() => {
                const { id, from } = attenteMotif;
                setAttenteMotif(null);
                move(id, from, 'PERDU', code);
              }}
              className="rounded-full border border-red-200 bg-white px-2.5 py-1 text-red-500 transition hover:bg-red-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-40 dark:border-red-900 dark:bg-transparent dark:hover:bg-red-950/40"
            >
              {label}
            </button>
          ))}
          <button
            type="button"
            onClick={() => setAttenteMotif(null)}
            className="rounded text-neutral-500 underline underline-offset-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
          >
            annuler
          </button>
        </div>
      ) : null}

      <div className="flex gap-3 overflow-x-auto pb-2">
        {cols.map((c) => {
          const isHover = hover === c.statut;
          return (
            <section
              key={c.statut}
              aria-label={STATUT_LABELS[c.statut] ?? c.statut}
              onDragOver={
                lectureSeule
                  ? undefined
                  : (e) => {
                      e.preventDefault();
                      setHover(c.statut);
                    }
              }
              onDragLeave={lectureSeule ? undefined : () => setHover((h) => (h === c.statut ? null : h))}
              onDrop={
                lectureSeule
                  ? undefined
                  : (e) => {
                      e.preventDefault();
                      setHover(null);
                      let d = dragRef.current;
                      dragRef.current = null;
                      if (!d) {
                        try {
                          d = JSON.parse(e.dataTransfer.getData('application/json'));
                        } catch {
                          d = null;
                        }
                      }
                      if (d) deposer(d, c.statut);
                    }
              }
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
              <div className="flex min-h-24 flex-col gap-2 p-2.5">
                {c.prospects.length === 0 ? (
                  <p className={`rounded-lg border border-dashed py-4 text-center text-[10px] transition ${isHover ? 'border-brand text-brand dark:border-accent dark:text-accent' : 'border-neutral-200 text-neutral-300 dark:border-navy-700 dark:text-neutral-600'}`}>
                    {lectureSeule ? 'Aucun prospect' : 'Déposer ici'}
                  </p>
                ) : (
                  c.prospects.map((p) => (
                    <div
                      key={p.id}
                      draggable={!lectureSeule}
                      onDragStart={
                        lectureSeule
                          ? undefined
                          : (e) => {
                              dragRef.current = { id: p.id, statut: c.statut };
                              e.dataTransfer.setData('application/json', JSON.stringify({ id: p.id, statut: c.statut }));
                              e.dataTransfer.effectAllowed = 'move';
                            }
                      }
                      onDragEnd={
                        lectureSeule
                          ? undefined
                          : () => {
                              dragRef.current = null;
                            }
                      }
                      className={`rounded-lg border border-neutral-100 bg-neutral-50 px-2.5 py-2 dark:border-navy-700 dark:bg-navy-800/40 ${
                        lectureSeule ? '' : 'cursor-grab active:cursor-grabbing'
                      }`}
                    >
                      <div className="flex items-center gap-1.5">
                        <ClassBadge value={p.niveauClass} size="xs" />
                        <Link
                          href={`/prospects/${p.id}`}
                          draggable={false}
                          className="truncate rounded text-xs font-medium hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
                        >
                          {p.enseigne}
                        </Link>
                      </div>
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
