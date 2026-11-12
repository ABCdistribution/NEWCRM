'use client';

import { useEffect, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { changerEtapeFiche } from '@/lib/prospect-actions';
import { MOTIFS_PERTE, estMotifPerte } from '@/lib/prospect-motifs';
import type { ProspectStatut } from '@/lib/api'; // type seulement : `@/lib/api` importe next/headers (serveur uniquement)
import { STATUT_LABELS } from './prospect-badges';

/** Les étapes dans l'ordre du pipeline (ordre de déclaration de STATUT_LABELS). */
const ETAPES = Object.keys(STATUT_LABELS) as ProspectStatut[];

const SELECT =
  'rounded-lg border border-neutral-200 bg-white px-2 py-1 text-xs outline-none transition focus:border-brand disabled:opacity-50';

/**
 * Changement d'étape d'un prospect depuis le tableau (remplace le glisser-déposer du Kanban).
 * Même règle que la fiche : le passage en « Perdu » demande d'abord le motif, l'étape ne change qu'une fois le motif
 * choisi. L'action serveur revérifie le rôle ; la page n'affiche ce sélecteur qu'aux rôles qui peuvent écrire.
 * Une fois « Gagné » ou « Perdu » enregistré, la ligne sort du tableau (qui ne liste que les étapes en cours).
 */
export function ProspectEtapeSelect({ id, statut, enseigne }: { id: string; statut: ProspectStatut; enseigne: string }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [valeur, setValeur] = useState<ProspectStatut>(statut);
  const [attenteMotif, setAttenteMotif] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  useEffect(() => {
    setValeur(statut);
  }, [statut]);

  const appliquer = (vers: ProspectStatut, motifPerte?: string) => {
    setErreur(null);
    startTransition(async () => {
      try {
        const res = await changerEtapeFiche(id, vers, motifPerte);
        if (res.error) {
          setErreur(res.error);
          setValeur(statut);
        }
      } catch {
        setErreur("L'étape n'a pas pu être enregistrée (session expirée ou API injoignable).");
        setValeur(statut);
      }
      router.refresh(); // resynchronise la ligne (ou la retire si le prospect est gagné / perdu)
    });
  };

  return (
    <div className="relative z-10 flex flex-col items-start gap-1">
      <select
        aria-label={`Étape de ${enseigne}`}
        value={valeur}
        disabled={pending}
        onChange={(e) => {
          const vers = e.target.value as ProspectStatut;
          if (!ETAPES.includes(vers) || vers === statut) return;
          if (vers === 'PERDU') {
            setValeur(vers);
            setAttenteMotif(true);
            return;
          }
          setAttenteMotif(false);
          setValeur(vers);
          appliquer(vers);
        }}
        className={SELECT}
      >
        {ETAPES.map((s) => (
          <option key={s} value={s}>
            {STATUT_LABELS[s]}
          </option>
        ))}
      </select>

      {attenteMotif ? (
        <div className="flex items-center gap-1.5">
          <select
            aria-label={`Motif de la perte de ${enseigne}`}
            defaultValue=""
            disabled={pending}
            onChange={(e) => {
              if (!estMotifPerte(e.target.value)) return;
              setAttenteMotif(false);
              appliquer('PERDU', e.target.value);
            }}
            className={SELECT}
          >
            <option value="" disabled>
              Motif de la perte…
            </option>
            {MOTIFS_PERTE.map(([code, label]) => (
              <option key={code} value={code}>
                {label}
              </option>
            ))}
          </select>
          <button
            type="button"
            onClick={() => {
              setAttenteMotif(false);
              setValeur(statut);
            }}
            className="rounded text-xs text-neutral-500 underline underline-offset-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
          >
            annuler
          </button>
        </div>
      ) : null}

      {erreur ? (
        <p role="alert" className="max-w-48 text-xs text-red-700">
          {erreur}
        </p>
      ) : null}
    </div>
  );
}
