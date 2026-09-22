'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
import { CheckCircle2, Circle, Search, Sprout, Store, Trash2 , FileText } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { EtapeOptionsDialog, type EtapeOptions } from './etape-options-dialog';
import {
  addEtape,
  moveEtape,
  removeEtape,
  searchCibles,
  toggleEtapeFaite,
  type CibleTournee,
} from '@/lib/tournee-actions';
import type { TourneeEtapeRow, MagasinGeoPoint, ProspectRow } from '@/lib/api';

type Day = { date: string; nom: string; label: string };

/** yyyy-mm-dd local du jour courant. */
function todayIso(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Ajout d'une étape dans une case jour : recherche mêlée prospects + magasins. */
function AddEtape({ date, onPick }: { date: string; onPick: (c: CibleTournee, date: string) => void }) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<CibleTournee[]>([]);
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const boxRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<number>(0);

  // Recherche serveur avec un léger debounce.
  useEffect(() => {
    window.clearTimeout(timerRef.current);
    if (query.trim().length < 2) {
      setResults([]);
      return;
    }
    timerRef.current = window.setTimeout(() => {
      searchCibles(query).then(setResults).catch(() => setResults([]));
    }, 250);
    return () => window.clearTimeout(timerRef.current);
  }, [query]);

  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  const pick = (c: CibleTournee) => {
    // La qualification (heure, RDV, accompagnement…) se fait dans le dialogue.
    onPick(c, date);
    setQuery('');
    setOpen(false);
  };

  return (
    <div ref={boxRef} className="relative mt-1">
      <div className="flex items-center gap-1 rounded-md border border-dashed border-neutral-300 px-1.5 dark:border-navy-600">
        <Search size={11} className="shrink-0 text-neutral-400" />
        <input
          type="text"
          value={query}
          disabled={pending}
          placeholder="+ prospect ou magasin…"
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          className="w-full min-w-0 bg-transparent py-1 text-[11px] outline-none placeholder:text-neutral-400 disabled:opacity-50"
        />
      </div>
      {open && query.trim().length >= 2 && !pending ? (
        <ul className="absolute left-0 top-full z-30 mt-1 max-h-56 w-72 overflow-y-auto rounded-lg border border-neutral-200 bg-white p-1 shadow-xl dark:border-navy-600 dark:bg-navy-900">
          {results.length === 0 ? (
            <li className="px-2 py-1.5 text-[11px] text-neutral-400">Aucun résultat…</li>
          ) : (
            results.map((c) => (
              <li key={`${c.type}-${c.id}`}>
                <button
                  type="button"
                  onClick={() => pick(c)}
                  className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-left transition hover:bg-neutral-100 dark:hover:bg-accent/20"
                >
                  {c.type === 'PROSPECT' ? (
                    <Sprout size={12} className="shrink-0 text-violet-500" />
                  ) : (
                    <Store size={12} className="shrink-0 text-sky-500" />
                  )}
                  <ClassBadge value={c.niveauClass} size="xs" />
                  <span className="min-w-0 flex-1 truncate text-[11px] font-medium">{c.enseigne}</span>
                  <span className="shrink-0 text-[10px] text-neutral-400">
                    {c.type === 'PROSPECT' ? 'Prospect' : c.ville ?? ''}
                  </span>
                </button>
              </li>
            ))
          )}
        </ul>
      ) : null}
    </div>
  );
}

type Drag =
  | { kind: 'etape'; id: string }
  | { kind: 'nouvelle'; type: 'CLIENT' | 'PROSPECT'; id: string; nom?: string }
  | { kind: 'nouvelle'; type: 'ADM'; id?: string; nom?: string };

/** Panneau de cibles à glisser dans la semaine (magasins du périmètre / prospects). */
function PanelCibles({
  titre,
  icone,
  items,
  type,
  onDragStart,
}: {
  titre: string;
  icone: React.ReactNode;
  items: { id: string; enseigne: string; raisonSociale?: string; ville: string | null; niveauClass: string | null }[];
  type: 'CLIENT' | 'PROSPECT';
  onDragStart: (d: Drag) => void;
}) {
  const [q, setQ] = useState('');
  const query = q.trim().toLowerCase();
  const visibles = (query === ''
    ? items
    : items.filter(
        (i) =>
          (i.enseigne || i.raisonSociale || '').toLowerCase().includes(query) ||
          (i.ville ?? '').toLowerCase().includes(query),
      )
  ).slice(0, 30);

  return (
    <section className="flex min-h-0 flex-1 flex-col rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-3 py-2 text-sm font-semibold dark:border-navy-700">
        {icone}
        {titre}
        <span className="ml-auto text-xs font-normal text-neutral-400">{items.length}</span>
      </h2>
      <div className="flex items-center gap-1.5 border-b border-neutral-100 px-3 py-1.5 dark:border-navy-700">
        <Search size={12} className="shrink-0 text-neutral-400" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Filtrer…"
          className="w-full bg-transparent py-1 text-xs outline-none placeholder:text-neutral-400"
        />
      </div>
      <ul className="min-h-0 flex-1 overflow-y-auto p-1.5">
        {visibles.map((i) => (
          <li key={i.id}>
            <div
              draggable
              onDragStart={() => onDragStart({ kind: 'nouvelle', type, id: i.id, nom: i.enseigne.trim() || i.raisonSociale || '' })}
              className="flex cursor-grab items-center gap-1.5 rounded-lg px-2 py-1.5 transition hover:bg-neutral-100 active:cursor-grabbing dark:hover:bg-navy-800"
              title="Glisser vers un jour de la semaine"
            >
              <ClassBadge value={i.niveauClass} size="xs" />
              <span className="min-w-0 flex-1 truncate text-xs font-medium">{i.enseigne.trim() || i.raisonSociale || "—"}</span>
              {i.ville ? <span className="shrink-0 text-[10px] text-neutral-400">{i.ville}</span> : null}
            </div>
          </li>
        ))}
        {visibles.length === 0 ? (
          <li className="px-2 py-3 text-center text-[11px] text-neutral-400">Aucun résultat.</li>
        ) : null}
      </ul>
    </section>
  );
}

/** Grille semaine de MON planning : étapes prospects (violet) et magasins (bleu), drag & drop entre jours. */
export function MaTourneeBoard({
  days,
  etapes,
  magasins,
  prospects,
}: {
  days: Day[];
  etapes: TourneeEtapeRow[];
  magasins: MagasinGeoPoint[];
  prospects: ProspectRow[];
}) {
  const [pending, startTransition] = useTransition();
  const [drag, setDrag] = useState<Drag | null>(null);
  // Nouvelle étape en attente de qualification (dialogue d'options).
  const [enAttente, setEnAttente] = useState<{ type: 'CLIENT' | 'PROSPECT' | 'ADM'; id?: string; nom: string; date: string } | null>(null);
  const aujourdhui = todayIso();

  const confirmer = (opts: EtapeOptions) => {
    if (!enAttente) return;
    const cible = enAttente;
    setEnAttente(null);
    startTransition(async () => {
      await addEtape({ type: cible.type, id: cible.id }, opts.date, {
        heure: opts.heure || undefined,
        visiteSimple: opts.visiteSimple,
        accompagnement: opts.accompagnement,
        rdv: opts.rdv,
        soireeEtape: opts.soireeEtape,
        soireeLieu: opts.soireeLieu || undefined,
        soireeAdresse: opts.soireeAdresse || undefined,
        note: opts.note || undefined,
      });
    });
  };

  const duJour = (date: string) =>
    etapes.filter((e) => e.datePassage.slice(0, 10) === date);

  const drop = (date: string) => {
    if (!drag) return;
    const d = drag;
    setDrag(null);
    if (d.kind === 'etape') {
      startTransition(async () => {
        await moveEtape(d.id, date);
      });
    } else {
      // Une NOUVELLE étape se qualifie avant l'ajout (heure, RDV, accompagnement…).
      setEnAttente({ type: d.type, id: d.id, nom: d.nom ?? (d.type === 'ADM' ? 'ADM' : 'la cible'), date });
    }
  };

  return (
    <div className={`flex flex-col gap-4 lg:flex-row ${pending ? 'opacity-70' : ''}`}>
      {enAttente ? (
        <EtapeOptionsDialog
          titre={`Planifier — ${enAttente.nom}`}
          dateInitiale={enAttente.date}
          onConfirm={confirmer}
          onClose={() => setEnAttente(null)}
          pending={pending}
        />
      ) : null}
      {/* Colonne « À planifier » — visuellement distincte des cartes de jours */}
      <aside className="flex shrink-0 flex-col gap-3 rounded-2xl border border-neutral-200 bg-neutral-100/70 p-2.5 lg:h-[calc(100vh-13rem)] lg:w-72 dark:border-navy-700 dark:bg-navy-900/50">
        <p className="px-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
          À planifier — glisser vers un jour
        </p>
        <PanelCibles
          titre="Magasins du secteur"
          icone={<Store size={14} className="text-sky-500" />}
          items={magasins}
          type="CLIENT"
          onDragStart={setDrag}
        />
        <PanelCibles
          titre="Prospects"
          icone={<Sprout size={14} className="text-violet-500" />}
          items={prospects}
          type="PROSPECT"
          onDragStart={setDrag}
        />

        {/* Autre : journée / plage administrative, à glisser comme une cible */}
        <div>
          <p className="flex items-center gap-1.5 px-1 pb-1.5 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
            <FileText size={14} className="text-amber-500" /> Autre
          </p>
          <div
            draggable
            onDragStart={() => setDrag({ kind: 'nouvelle', type: 'ADM', nom: 'ADM' })}
            className="flex cursor-grab items-center gap-2 rounded-lg border border-dashed border-amber-300 bg-amber-50/60 px-2.5 py-2 active:cursor-grabbing dark:border-amber-800 dark:bg-amber-950/20"
            title="Glisser vers un jour pour planifier une plage administrative"
          >
            <FileText size={13} className="shrink-0 text-amber-500" />
            <span className="text-xs font-medium">ADM</span>
            <span className="ml-auto text-[10px] text-neutral-400">administratif</span>
          </div>
        </div>
      </aside>

      {/* Semaine (lundi → vendredi) */}
      <div className="grid min-w-0 flex-1 grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
      {days.map((day) => (
        <section
          key={day.date}
          onDragOver={(e) => e.preventDefault()}
          onDrop={() => drop(day.date)}
          className={`flex min-h-40 flex-col rounded-2xl bg-white p-2.5 shadow-card ${
            day.date === aujourdhui ? 'ring-2 ring-brand/40 dark:ring-accent/40' : ''
          }`}
        >
          <p className="flex items-baseline gap-1.5 px-1 pb-1.5">
            <span className="text-sm font-semibold">{day.nom}</span>
            <span className="text-[11px] text-neutral-400">{day.label}</span>
            <span className="ml-auto text-[11px] text-neutral-400">{duJour(day.date).length}</span>
          </p>
          <ul className="flex flex-1 flex-col gap-1.5">
            {duJour(day.date).map((e) => {
              const prospect = e.prospect != null;
              const cible = e.prospect ?? e.client ?? { enseigne: 'ADM — administratif', ville: null, niveauClass: null };
              const enRetard = !e.fait && day.date < aujourdhui;
              return (
                <li
                  key={e.id}
                  draggable
                  onDragStart={() => setDrag({ kind: 'etape', id: e.id })}
                  className={`group cursor-grab rounded-lg border-l-2 px-2 py-1.5 active:cursor-grabbing ${
                    e.fait
                      ? 'border-emerald-400 bg-emerald-500/10'
                      : enRetard
                        ? 'border-red-400 bg-red-500/10'
                        : e.adm
                          ? 'border-amber-400 bg-amber-500/10'
                          : prospect
                            ? 'border-violet-400 bg-violet-500/10'
                            : 'border-sky-400 bg-sky-500/10'
                  }`}
                >
                  <div className="flex items-center gap-1.5">
                    {e.adm ? (
                      <FileText size={12} className="shrink-0 text-amber-500" />
                    ) : prospect ? (
                      <Sprout size={12} className="shrink-0 text-violet-500" />
                    ) : (
                      <Store size={12} className="shrink-0 text-sky-500" />
                    )}
                    <ClassBadge value={cible.niveauClass} size="xs" />
                    <span className="min-w-0 flex-1 truncate text-xs font-medium">{cible.enseigne}</span>
                  </div>
                  <div className="mt-1 flex items-center gap-1">
                    <span className="min-w-0 truncate text-[10px] text-neutral-400">
                      {[
                        e.datePassage.slice(11, 16) !== '00:00' && e.datePassage.length > 10
                          ? e.datePassage.slice(11, 16)
                          : null,
                        e.adm ? 'Administratif' : prospect ? 'Prospection' : e.accompagnement ? 'Accomp. promoteur' : 'Suivi magasin',
                        e.rdv ? 'RDV' : null,
                        e.soireeEtape ? 'Soirée étape' : null,
                        cible.ville,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </span>
                    <button
                      type="button"
                      onClick={() => startTransition(async () => void (await toggleEtapeFaite(e.id, !e.fait)))}
                      className="ml-auto rounded p-0.5 text-neutral-400 transition hover:text-emerald-500"
                      title={e.fait ? 'Marquer non faite' : 'Marquer faite'}
                      aria-label={e.fait ? 'Marquer non faite' : 'Marquer faite'}
                    >
                      {e.fait ? <CheckCircle2 size={13} className="text-emerald-500" /> : <Circle size={13} />}
                    </button>
                    <button
                      type="button"
                      onClick={() => startTransition(async () => removeEtape(e.id))}
                      className="rounded p-0.5 text-neutral-400 opacity-0 transition hover:text-red-500 group-hover:opacity-100"
                      title="Retirer de mon planning"
                      aria-label="Retirer de mon planning"
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
          <AddEtape date={day.date} onPick={(c, date) => setEnAttente({ type: c.type, id: c.id, nom: c.enseigne, date })} />
        </section>
      ))}
      </div>
    </div>
  );
}
