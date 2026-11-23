'use client';

import { useState, useTransition } from 'react';
import { ClipboardCheck } from 'lucide-react';
import { changerSuiviPem } from '@/lib/pem-actions';
import { formaterJourPem, libelleSemaines, type PropositionPem } from '@/lib/pem';

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

/**
 * Indicateur « Suivi PEM » de la fiche client : pastille Oui / Non pour tous, interrupteur pour les rôles qui
 * l'administrent (`peutAdministrer`, calculé par la page ; la Server Action et l'API restent juges, le directeur
 * régional étant limité à sa région). Désactiver demande une confirmation : la proposition ouverte est annulée.
 */
export function PemSuiviCard({
  clientId,
  suiviPem,
  peutAdministrer,
  frequenceSemaines,
  propositionOuverte,
}: {
  clientId: string;
  suiviPem: boolean;
  peutAdministrer: boolean;
  /** Fréquence des visites PEM de la classe du magasin (null si inconnue). */
  frequenceSemaines: number | null;
  /** Proposition ouverte du magasin au chargement de la page (null si aucune). */
  propositionOuverte?: PropositionPem | null;
}) {
  const [actif, setActif] = useState(suiviPem);
  const [confirmation, setConfirmation] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);
  const [proposition, setProposition] = useState<PropositionPem | null>(propositionOuverte ?? null);
  const [aucuneVisite, setAucuneVisite] = useState(false);
  const [enCours, demarrer] = useTransition();

  const appliquer = (valeur: boolean) => {
    const fd = new FormData();
    fd.set('clientId', clientId);
    fd.set('suiviPem', String(valeur));
    demarrer(async () => {
      const reponse = await changerSuiviPem(fd);
      if (reponse.error !== null) {
        setErreur(reponse.error);
        return;
      }
      setErreur(null);
      setConfirmation(false);
      setActif(reponse.suiviPem);
      setProposition(reponse.proposition);
      setAucuneVisite(reponse.suiviPem && !reponse.proposition);
    });
  };

  const basculer = () => {
    setErreur(null);
    if (actif) setConfirmation(true);
    else appliquer(true);
  };

  return (
    <div className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
        <ClipboardCheck size={17} className="text-brand" />
        Suivi PEM
        <span
          className={`ml-auto rounded-full px-2.5 py-0.5 text-xs font-semibold ${
            actif ? 'bg-emerald-500/10 text-emerald-700' : 'bg-neutral-100 text-neutral-600'
          }`}
        >
          {actif ? 'Oui' : 'Non'}
        </span>
      </h2>

      <div className="flex flex-col gap-3 px-5 py-4">
        {actif && frequenceSemaines !== null ? (
          <p className="text-sm text-neutral-600">Visite PEM tous les {libelleSemaines(frequenceSemaines)}.</p>
        ) : null}

        {peutAdministrer ? (
          <div className="flex items-center gap-3">
            <button
              type="button"
              role="switch"
              aria-checked={actif}
              aria-label="Magasin soumis au suivi PEM"
              disabled={enCours || confirmation}
              onClick={basculer}
              className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition disabled:opacity-50 ${FOCUS} ${
                actif ? 'bg-brand' : 'bg-neutral-300'
              }`}
            >
              <span
                aria-hidden
                className={`inline-block h-5 w-5 rounded-full bg-white shadow transition-transform ${
                  actif ? 'translate-x-5' : 'translate-x-0.5'
                }`}
              />
            </button>
            <span className="text-sm">{enCours ? 'Enregistrement…' : actif ? 'Activé' : 'Désactivé'}</span>
          </div>
        ) : null}

        {confirmation ? (
          <div role="alertdialog" aria-label="Confirmer la désactivation du suivi PEM" className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2.5 text-sm text-amber-800">
            <p>Désactiver le suivi PEM annule la proposition de visite en cours.</p>
            <div className="mt-2 flex flex-wrap gap-2">
              <button
                type="button"
                disabled={enCours}
                onClick={() => appliquer(false)}
                className={`rounded-xl bg-brand px-3 py-1.5 text-xs font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 ${FOCUS}`}
              >
                {enCours ? '…' : 'Désactiver'}
              </button>
              <button
                type="button"
                disabled={enCours}
                onClick={() => setConfirmation(false)}
                className={`rounded-xl border border-neutral-300 bg-white px-3 py-1.5 text-xs font-medium text-neutral-700 transition hover:border-brand hover:text-brand disabled:opacity-50 ${FOCUS}`}
              >
                Annuler
              </button>
            </div>
          </div>
        ) : null}

        {erreur ? (
          <p role="alert" className="text-xs text-red-600">
            {erreur}
          </p>
        ) : null}

        <div aria-live="polite">
          {proposition ? (
            <p className="rounded-lg bg-brand/10 px-3 py-2 text-sm text-brand">
              Prochaine visite PEM proposée le {formaterJourPem(proposition.dateProposee)}
              {proposition.promoteur ? ` à ${proposition.promoteur.displayName}` : ''}.
            </p>
          ) : aucuneVisite ? (
            <p className="text-sm text-neutral-500">Suivi PEM activé : aucune visite à proposer pour le moment.</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
