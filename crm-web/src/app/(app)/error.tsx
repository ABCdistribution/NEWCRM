'use client';

import { useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { TriangleAlert, RefreshCw } from 'lucide-react';

/**
 * Page d'erreur de l'application connectée (une erreur levée par une page ou une Server Action, par exemple un
 * dépôt de fichier rejeté ou une API indisponible). Elle remplace uniquement le contenu : le menu reste affiché.
 * Elle n'attrape PAS les erreurs du layout (app) lui-même, qui gère l'API indisponible à part (voir `app/error.tsx`).
 *
 * En production, Next remplace le message des erreurs levées côté serveur par un simple identifiant (`digest`) :
 * le texte affiché est donc générique, accompagné de cette référence pour l'équipe technique.
 */
export default function ErreurApplication({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const router = useRouter();
  const [enCours, startTransition] = useTransition();

  // `reset()` seul ne rejoue que le rendu côté navigateur : l'erreur venant du serveur, il faut AUSSI relire la page
  // (router.refresh). Les deux dans la même transition, pour que la frontière d'erreur se réinitialise avec les
  // nouvelles données.
  const reessayer = () =>
    startTransition(() => {
      router.refresh();
      reset();
    });

  return (
    <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
      <h1 className="flex items-center gap-2 text-lg font-semibold">
        <TriangleAlert size={20} aria-hidden />
        Une erreur est survenue
      </h1>
      <p className="mt-1 text-sm">
        L&apos;opération n&apos;a pas pu aboutir. Réessayez dans un instant ; si le problème continue, prévenez votre
        administrateur.
      </p>
      {error.digest ? <p className="mt-2 text-xs text-red-700/80">Référence : {error.digest}</p> : null}
      <button
        type="button"
        onClick={reessayer}
        disabled={enCours}
        className="mt-4 inline-flex items-center gap-2 rounded-lg bg-red-700 px-3.5 py-2 text-sm font-medium text-white transition hover:bg-red-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-700 disabled:opacity-60"
      >
        <RefreshCw size={14} aria-hidden className={enCours ? 'animate-spin' : ''} />
        {enCours ? 'Nouvelle tentative…' : 'Réessayer'}
      </button>
    </div>
  );
}
