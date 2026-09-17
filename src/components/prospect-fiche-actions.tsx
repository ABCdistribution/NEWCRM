'use client';

import { useState, useTransition } from 'react';
import { CalendarPlus, Check, StickyNote } from 'lucide-react';
import type { ProspectStatut } from '@/lib/api';

// Étapes dans l'ordre du pipeline — dupliquées ici : importer la constante
// depuis lib/api tirerait next/headers (session) dans le bundle client.
const PROSPECT_STATUTS: ProspectStatut[] = ['NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION', 'GAGNE', 'PERDU'];
import { STATUT_LABELS } from '@/components/prospect-badges';
import { changerEtapeFiche, addNoteFiche } from '@/lib/prospect-actions';
import { addEtape } from '@/lib/tournee-actions';
import { EtapeOptionsDialog } from './etape-options-dialog';

const MOTIFS_PERTE = [
  ['PRIX', 'Prix'],
  ['CONCURRENCE', 'Concurrent en place'],
  ['PAS_DE_BESOIN', 'Pas de besoin'],
  ['SANS_REPONSE', 'Sans réponse'],
  ['AUTRE', 'Autre'],
] as const;

/**
 * Stepper du pipeline sur la fiche : les étapes dans l'ordre, l'actuelle mise
 * en avant — un clic change l'étape (journalisé dans la timeline). Le passage
 * en Perdu demande un motif.
 */
export function ProspectEtapesStepper({ prospectId, statut }: { prospectId: string; statut: ProspectStatut }) {
  const [pending, startTransition] = useTransition();
  const [motifOuvert, setMotifOuvert] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  const aller = (s: ProspectStatut, motif?: string) => {
    setErreur(null);
    setMotifOuvert(false);
    startTransition(async () => {
      const { error } = await changerEtapeFiche(prospectId, s, motif);
      if (error) setErreur(error);
    });
  };

  const index = PROSPECT_STATUTS.indexOf(statut);

  return (
    <div className="flex flex-col gap-2">
      <ol className="flex flex-wrap items-center gap-1.5">
        {PROSPECT_STATUTS.map((s, i) => {
          const actuel = s === statut;
          const passe = i < index && statut !== 'PERDU';
          return (
            <li key={s} className="flex items-center gap-1.5">
              {i > 0 ? <span className="h-px w-3 bg-neutral-200 dark:bg-navy-700" /> : null}
              <button
                type="button"
                disabled={pending || actuel}
                onClick={() => (s === 'PERDU' ? setMotifOuvert(true) : aller(s))}
                title={actuel ? 'Étape actuelle' : `Passer à « ${STATUT_LABELS[s]} »`}
                className={`rounded-full border px-2.5 py-1 text-xs font-medium transition disabled:cursor-default ${
                  actuel
                    ? s === 'GAGNE'
                      ? 'border-emerald-500 bg-emerald-500 text-white'
                      : s === 'PERDU'
                        ? 'border-red-500 bg-red-500 text-white'
                        : 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
                    : passe
                      ? 'border-emerald-200 bg-emerald-50 text-emerald-600 dark:border-emerald-900 dark:bg-emerald-950/30'
                      : 'border-neutral-200 text-neutral-400 hover:border-brand hover:text-brand dark:border-navy-700 dark:hover:border-accent dark:hover:text-accent'
                }`}
              >
                {passe ? <Check size={11} className="mr-1 inline" /> : null}
                {STATUT_LABELS[s]}
              </button>
            </li>
          );
        })}
      </ol>
      {motifOuvert ? (
        <div className="flex flex-wrap items-center gap-1.5 text-xs">
          <span className="font-medium text-red-500">Motif de la perte :</span>
          {MOTIFS_PERTE.map(([code, label]) => (
            <button
              key={code}
              type="button"
              onClick={() => aller('PERDU', code)}
              className="rounded-full border border-red-200 px-2.5 py-1 text-red-500 transition hover:bg-red-50 dark:border-red-900 dark:hover:bg-red-950/40"
            >
              {label}
            </button>
          ))}
          <button type="button" onClick={() => setMotifOuvert(false)} className="text-neutral-400 underline underline-offset-2">
            annuler
          </button>
        </div>
      ) : null}
      {erreur ? <p className="text-xs text-red-500">{erreur}</p> : null}
    </div>
  );
}

/** Note libre : enregistrée dans la timeline de la fiche. */
export function ProspectNoteForm({ prospectId }: { prospectId: string }) {
  const [texte, setTexte] = useState('');
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const enregistrer = () => {
    startTransition(async () => {
      const { error } = await addNoteFiche(prospectId, texte);
      if (error) setErreur(error);
      else {
        setTexte('');
        setErreur(null);
      }
    });
  };

  return (
    <div className="flex items-start gap-2 px-5 py-3">
      <textarea
        value={texte}
        onChange={(e) => setTexte(e.target.value)}
        rows={2}
        placeholder="Ajouter une note à la timeline…"
        className="min-w-0 flex-1 rounded-xl border border-neutral-200 px-3 py-2 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
      />
      <div className="flex flex-col items-end gap-1">
        <button
          type="button"
          onClick={enregistrer}
          disabled={pending || !texte.trim()}
          className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
        >
          <StickyNote size={13} /> Noter
        </button>
        {erreur ? <span className="text-xs text-red-500">{erreur}</span> : null}
      </div>
    </div>
  );
}

/**
 * Planifie une visite de prospection dans MON planning d'activité : le bouton
 * ouvre le dialogue de qualification (date, heure, RDV, accompagnement,
 * soirée étape, observations) avant l'ajout.
 */
export function ProspectPlanifierButton({ prospectId }: { prospectId: string }) {
  const demain = () => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().slice(0, 10);
  };
  const [ouvert, setOuvert] = useState(false);
  const [etat, setEtat] = useState<'idle' | 'ok' | 'erreur'>('idle');
  const [pending, startTransition] = useTransition();

  if (etat === 'ok') {
    return (
      <p className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-600">
        <Check size={14} /> Visite planifiée —{' '}
        <a href="/pilotage/ma-tournee" className="underline underline-offset-2">
          ouvrir Mon planning
        </a>
      </p>
    );
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setOuvert(true)}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <CalendarPlus size={13} /> Planifier une visite
      </button>
      {ouvert ? (
        <EtapeOptionsDialog
          titre="Planifier une visite de prospection"
          dateInitiale={demain()}
          pending={pending}
          onClose={() => setOuvert(false)}
          onConfirm={(opts) => {
            setOuvert(false);
            startTransition(async () => {
              const { error } = await addEtape({ type: 'PROSPECT', id: prospectId }, opts.date, {
                heure: opts.heure || undefined,
                visiteSimple: opts.visiteSimple,
                accompagnement: opts.accompagnement,
                rdv: opts.rdv,
                soireeEtape: opts.soireeEtape,
        soireeLieu: opts.soireeLieu || undefined,
        soireeAdresse: opts.soireeAdresse || undefined,
                note: opts.note || undefined,
              });
              setEtat(error ? 'erreur' : 'ok');
            });
          }}
        />
      ) : null}
      {etat === 'erreur' ? <span className="text-xs text-red-500">Échec — réessayer.</span> : null}
    </>
  );
}
