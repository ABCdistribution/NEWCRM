'use client';

import { useState, useTransition } from 'react';
import { BadgeCheck, Hourglass, Lock, Save } from 'lucide-react';
import { enregistrerSemaine } from '@/lib/tournee-actions';
import type { SemaineEtat } from '@/lib/api';
import { FUSEAU } from '@/lib/planning-dates';

// Fuseau explicite : l'heure affichée est la même au rendu serveur et dans le navigateur.
const FMT = new Intl.DateTimeFormat('fr-FR', { timeZone: FUSEAU, day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
const dateHeure = (iso: string) => FMT.format(new Date(iso));

const pastille = 'inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold';

/**
 * Les trois temps du rapport d'activité d'une semaine :
 *  1. tournée prévue : on enregistre la prévision (brouillon, autant de fois que voulu) jusqu'au lundi soir ; elle est
 *     figée dès le mardi ;
 *  2. tournée réalisée : dès le mardi, on corrige les étapes pour refléter la réalité, puis on valide le rapport ;
 *  3. rapport validé : la semaine est verrouillée, plus rien n'est modifiable.
 * Enregistrés côté serveur (`/tournees/semaine`), partagés avec l'application mobile.
 */
export function PlanningValidation({ semaine, nbEtapes, etat }: { semaine: string; nbEtapes: number; etat: SemaineEtat | null }) {
  const [pending, start] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  if (!etat) return null;

  const enregistrer = (etape: 'prevision' | 'validation') => {
    if (etape === 'validation' && !window.confirm('Valider le rapport ? La semaine sera verrouillée : plus rien ne sera modifiable.')) return;
    start(async () => {
      const r = await enregistrerSemaine(semaine, etape);
      setErreur(r.error);
    });
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      {/* Où en est la semaine */}
      {etat.verrouillee ? (
        <span className={`${pastille} bg-emerald-500/12 text-emerald-600 dark:text-emerald-400`}>
          {etat.valideAuto ? <Lock size={13} /> : <BadgeCheck size={14} />}
          {etat.valideAuto ? 'Validé auto' : 'Rapport validé'} le {dateHeure(etat.valideAt!)}
        </span>
      ) : etat.phase === 'PREVISION' ? (
        etat.prevuAt ? (
          <span className={`${pastille} bg-sky-500/12 text-sky-600 dark:text-sky-400`}>
            <Save size={13} /> Prévision enregistrée le {dateHeure(etat.prevuAt)}
          </span>
        ) : (
          <span className={`${pastille} bg-neutral-500/10 text-neutral-500`}>Prévision à saisir</span>
        )
      ) : (
        <>
          <span className={`${pastille} bg-amber-500/12 text-amber-600 dark:text-amber-400`}>
            <Hourglass size={13} /> Rapport en cours
          </span>
          <span className={`${pastille} bg-neutral-500/10 text-neutral-500`}>
            {etat.previsionNonRenseignee ? 'Prévision non renseignée' : `Prévision figée (${etat.nbEtapesPrevues ?? 0} lignes)`}
          </span>
        </>
      )}

      {/* Phase prévision : enregistrer (autant de fois que voulu jusqu'au lundi soir) */}
      {etat.previsionModifiable ? (
        <button
          type="button"
          onClick={() => enregistrer('prevision')}
          disabled={nbEtapes === 0 || pending}
          title={nbEtapes === 0 ? 'La prévision ne peut pas être vide' : `Enregistrer la prévision (${nbEtapes} lignes)`}
          className="inline-flex items-center gap-1.5 rounded-xl border border-neutral-200 bg-white px-3 py-1.5 text-xs font-semibold text-neutral-600 shadow-sm transition hover:border-brand hover:text-brand disabled:opacity-40 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-300 dark:hover:border-accent dark:hover:text-accent"
        >
          <Save size={13} /> {etat.prevuAt ? 'Mettre à jour la prévision' : 'Enregistrer la prévision'}
        </button>
      ) : null}

      {/* Phase rapport : valider (dès le mardi) */}
      {etat.peutValider ? (
        <button
          type="button"
          onClick={() => enregistrer('validation')}
          disabled={pending}
          className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
        >
          <BadgeCheck size={14} /> Valider le rapport
        </button>
      ) : null}

      {/* Avant le mardi : pas de validation, on l'explique */}
      {etat.previsionModifiable ? (
        <span className="text-xs text-neutral-400">
          La prévision est encore modifiable (jusqu&apos;au lundi soir) : le rapport se valide à partir du mardi.
        </span>
      ) : null}
      {erreur ? <span role="alert" className="text-xs font-medium text-red-700">{erreur}</span> : null}
    </div>
  );
}
