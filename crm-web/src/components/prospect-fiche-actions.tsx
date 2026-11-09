'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { CalendarPlus, Check, StickyNote } from 'lucide-react';
import type { ProspectStatut } from '@/lib/api';
import { aujourdhuiParis, iso, mondayOf } from '@/lib/planning-dates';

// Étapes dans l'ordre du pipeline — dupliquées ici : importer la constante
// depuis lib/api tirerait next/headers (session) dans le bundle client.
const PROSPECT_STATUTS: ProspectStatut[] = ['NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION', 'GAGNE', 'PERDU'];
import { STATUT_LABELS } from '@/components/prospect-badges';
import { changerEtapeFiche, addNoteFiche } from '@/lib/prospect-actions';
import { MOTIFS_PERTE, type MotifPerteCode } from '@/lib/prospect-motifs';
import { addEtape } from '@/lib/tournee-actions';
import { EtapeOptionsDialog } from './etape-options-dialog';

/**
 * Stepper du pipeline sur la fiche : les étapes dans l'ordre, l'actuelle mise
 * en avant — un clic change l'étape (journalisé dans la timeline). Le passage
 * en Perdu demande un motif. `lectureSeule` (rôle sans droit d'écriture sur les
 * prospects, ex. DIRECTION) : l'étape est affichée mais les boutons sont inactifs.
 */
export function ProspectEtapesStepper({
  prospectId,
  statut,
  lectureSeule = false,
}: {
  prospectId: string;
  statut: ProspectStatut;
  lectureSeule?: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [motifOuvert, setMotifOuvert] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  const aller = (s: ProspectStatut, motif?: MotifPerteCode) => {
    if (lectureSeule) return;
    setErreur(null);
    setMotifOuvert(false);
    startTransition(async () => {
      try {
        const { error } = await changerEtapeFiche(prospectId, s, motif);
        if (error) setErreur(error);
      } catch {
        setErreur("Le changement d'étape n'a pas pu être enregistré (session expirée ou API injoignable).");
      }
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
                disabled={pending || actuel || lectureSeule}
                aria-current={actuel ? 'step' : undefined}
                onClick={() => (s === 'PERDU' ? setMotifOuvert(true) : aller(s))}
                title={actuel ? 'Étape actuelle' : lectureSeule ? STATUT_LABELS[s] : `Passer à « ${STATUT_LABELS[s]} »`}
                className={`rounded-full border px-2.5 py-1 text-xs font-medium transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand disabled:cursor-default ${
                  actuel
                    ? s === 'GAGNE'
                      ? 'border-emerald-700 bg-emerald-700 text-white'
                      : s === 'PERDU'
                        ? 'border-red-700 bg-red-700 text-white'
                        : 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
                    : passe
                      ? 'border-emerald-200 bg-emerald-50 text-emerald-600 dark:border-emerald-900 dark:bg-emerald-950/30'
                      : lectureSeule
                        ? 'border-neutral-200 text-neutral-400 dark:border-navy-700'
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
          <span className="font-medium text-red-700">Motif de la perte :</span>
          {MOTIFS_PERTE.map(([code, label]) => (
            <button
              key={code}
              type="button"
              onClick={() => aller('PERDU', code)}
              className="rounded-full border border-red-200 px-2.5 py-1 text-red-700 transition hover:bg-red-50 dark:border-red-900 dark:hover:bg-red-950/40"
            >
              {label}
            </button>
          ))}
          <button type="button" onClick={() => setMotifOuvert(false)} className="text-neutral-400 underline underline-offset-2">
            annuler
          </button>
        </div>
      ) : null}
      {erreur ? <p role="alert" className="text-xs text-red-700">{erreur}</p> : null}
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
        aria-label="Note à ajouter à la timeline"
        placeholder="Ajouter une note à la timeline…"
        className="min-w-0 flex-1 rounded-xl border border-neutral-200 px-3 py-2 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/30 dark:border-navy-700 dark:bg-navy-950"
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
        {erreur ? <span role="alert" className="text-xs text-red-700">{erreur}</span> : null}
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
    // Demain À PARIS (jour de la plateforme), quel que soit le fuseau du navigateur.
    const d = aujourdhuiParis();
    d.setDate(d.getDate() + 1);
    return iso(d);
  };
  const [ouvert, setOuvert] = useState(false);
  const [etat, setEtat] = useState<'idle' | 'ok' | 'erreur'>('idle');
  // Date (yyyy-mm-dd) choisie dans le dialogue : le lien de confirmation ouvre la semaine qui la contient.
  const [dateChoisie, setDateChoisie] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  if (etat === 'ok') {
    const jour = dateChoisie ? new Date(`${dateChoisie}T12:00:00`) : null;
    const lien = jour && !Number.isNaN(jour.getTime()) ? `/planning?semaine=${iso(mondayOf(jour))}` : '/planning';
    return (
      <p className="inline-flex items-center gap-1.5 text-xs font-semibold text-emerald-600">
        <Check size={14} /> Visite planifiée —{' '}
        <Link
          href={lien}
          className="underline underline-offset-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
        >
          ouvrir Mon planning
        </Link>
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
              try {
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
                if (!error) setDateChoisie(opts.date);
                setEtat(error ? 'erreur' : 'ok');
              } catch {
                // Requête rejetée avant l'action (session expirée, API ou réseau indisponible).
                setEtat('erreur');
              }
            });
          }}
        />
      ) : null}
      {etat === 'erreur' ? <span role="alert" className="text-xs text-red-700">Échec — réessayer.</span> : null}
    </>
  );
}
