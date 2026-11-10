'use client';

import { useActionState, useEffect, useState } from 'react';
import { CheckCircle2, RefreshCw, TriangleAlert, XCircle } from 'lucide-react';
import { syncAd, type AdSyncState } from '@/lib/admin-actions';

const INITIAL: AdSyncState = { error: null, ok: false };

/** Nombre de noms listés dans un avertissement avant de résumer (« … et 3 autres »). */
const NOMS_MAX = 8;

const nomsEtReste = (noms: string[]) =>
  noms.length > NOMS_MAX ? `${noms.slice(0, NOMS_MAX).join(', ')} … et ${noms.length - NOMS_MAX} autres` : noms.join(', ');

/** Secondes écoulées depuis le début de l'attente (0 hors attente) : montre que la synchro n'est pas figée. */
function useSecondes(actif: boolean): number {
  const [secondes, setSecondes] = useState(0);
  useEffect(() => {
    if (!actif) return;
    const debut = Date.now();
    setSecondes(0);
    const id = setInterval(() => setSecondes(Math.floor((Date.now() - debut) / 1000)), 1000);
    return () => clearInterval(id);
  }, [actif]);
  return actif ? secondes : 0;
}

function Avertissement({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-2 flex items-start gap-1.5 text-amber-800">
      <TriangleAlert size={15} className="mt-0.5 shrink-0" aria-hidden />
      <span>{children}</span>
    </p>
  );
}

/**
 * Retour de la synchro (rendu pur) : consigne pendant l'attente (`role="status"`), échec avec sa cause
 * (`role="alert"`), succès avec le détail et les avertissements (`role="status"`). Annoncé aux lecteurs d'écran,
 * il reste affiché jusqu'au prochain lancement.
 */
export function RetourSynchro({ state, pending }: { state: AdSyncState; pending: boolean }) {
  if (pending) {
    return (
      <p role="status" className="text-sm text-neutral-600 sm:text-right">
        Lecture de l&apos;annuaire en cours : cela peut durer jusqu&apos;à 3 minutes. Restez sur cette page, le résultat
        s&apos;affichera ici.
      </p>
    );
  }

  if (state.error) {
    return (
      <div
        role="alert"
        className="flex w-full items-start gap-2.5 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
      >
        <XCircle size={18} className="mt-0.5 shrink-0" aria-hidden />
        <div>
          <p className="font-semibold">La synchronisation a échoué</p>
          <p className="mt-0.5">{state.error}</p>
        </div>
      </div>
    );
  }

  const stats = state.ok ? state.stats : undefined;
  if (!stats) return null;
  return (
    <div
      role="status"
      className="flex w-full items-start gap-2.5 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900"
    >
      <CheckCircle2 size={18} className="mt-0.5 shrink-0" aria-hidden />
      <div className="min-w-0">
        <p className="font-semibold">Synchronisation réussie</p>
        <p className="mt-0.5">
          {stats.lus} comptes lus · {stats.crees} créés · {stats.maj} mis à jour · {stats.photos ?? 0} photos rapatriées ·{' '}
          {stats.directeursLies} rattachés à un directeur
        </p>
        {stats.tronque ? (
          <Avertissement>
            La lecture de l&apos;annuaire a atteint sa limite (1 000 comptes) : des comptes de la force de vente ont pu être
            ignorés. Prévenez l&apos;équipe technique.
          </Avertissement>
        ) : null}
        {stats.sansRegion.length > 0 ? (
          <Avertissement>
            {stats.sansRegion.length} compte{stats.sansRegion.length > 1 ? 's' : ''} sans région reconnue :{' '}
            {nomsEtReste(stats.sansRegion)}
          </Avertissement>
        ) : null}
        {stats.conflitsIdRepr.length > 0 ? (
          <Avertissement>Codes en conflit : {nomsEtReste(stats.conflitsIdRepr)}</Avertissement>
        ) : null}
      </div>
    </div>
  );
}

/** Synchronisation en masse de la force de vente française depuis l'AD. */
export function AdSyncTrigger() {
  const [state, action, pending] = useActionState(syncAd, INITIAL);
  const secondes = useSecondes(pending);

  return (
    <form action={action} className="flex w-full max-w-md flex-col items-stretch gap-3 sm:items-end">
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center justify-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <RefreshCw size={14} className={pending ? 'animate-spin' : ''} aria-hidden />
        {pending ? `Synchronisation… ${secondes} s` : "Synchroniser depuis l'AD"}
      </button>
      <RetourSynchro state={state} pending={pending} />
    </form>
  );
}
