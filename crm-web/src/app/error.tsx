'use client';

import Link from 'next/link';
import { RefreshCw, TriangleAlert } from 'lucide-react';

/**
 * Page d'erreur de la racine : une erreur levée hors de l'application connectée (par exemple la page de
 * connexion) ou par le layout (app) lui-même, que `(app)/error.tsx` n'attrape pas. Il n'y a pas de menu ici :
 * l'écran est donc centré, avec un retour à l'accueil. Les erreurs des pages connectées passent par
 * `(app)/error.tsx`, qui garde le menu affiché.
 */
export default function ErreurRacine({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-8">
      <div role="alert" className="w-full max-w-md rounded-xl border border-red-200 bg-white p-6 text-neutral-800 shadow-sm">
        <h1 className="flex items-center gap-2 text-lg font-semibold text-red-700">
          <TriangleAlert size={20} aria-hidden />
          Une erreur est survenue
        </h1>
        <p className="mt-2 text-sm text-neutral-600">
          La page n&apos;a pas pu s&apos;afficher. Réessayez dans un instant ; si le problème continue, prévenez votre
          administrateur.
        </p>
        {error.digest ? <p className="mt-2 text-xs text-neutral-500">Référence : {error.digest}</p> : null}
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => reset()}
            className="inline-flex items-center gap-2 rounded-lg bg-brand px-3.5 py-2 text-sm font-medium text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          >
            <RefreshCw size={14} aria-hidden />
            Réessayer
          </button>
          <Link
            href="/"
            className="rounded-lg px-2 py-2 text-sm font-medium text-brand underline-offset-2 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          >
            Retour à l&apos;accueil
          </Link>
        </div>
      </div>
    </main>
  );
}
