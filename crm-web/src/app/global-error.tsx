'use client';

import './globals.css';

/**
 * Dernier filet : une erreur dans le layout racine lui-même. Ce composant REMPLACE le layout racine : il doit donc
 * rendre ses propres balises <html> et <body>, et réimporter la feuille de styles (le layout racine, qui l'importe
 * d'habitude, n'est pas rendu). Pas de composant de l'application ici (le routeur peut être indisponible) :
 * « Réessayer » relance le rendu, le lien recharge l'accueil par une vraie navigation.
 */
export default function ErreurGlobale({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="fr">
      <body>
        <main className="flex min-h-screen items-center justify-center px-4 py-8">
          <div role="alert" className="w-full max-w-md rounded-xl border border-red-200 bg-white p-6 text-neutral-800 shadow-sm">
            <h1 className="text-lg font-semibold text-red-700">Une erreur est survenue</h1>
            <p className="mt-2 text-sm text-neutral-600">
              L&apos;application n&apos;a pas pu s&apos;afficher. Réessayez dans un instant ; si le problème continue,
              prévenez votre administrateur.
            </p>
            {error.digest ? <p className="mt-2 text-xs text-neutral-500">Référence : {error.digest}</p> : null}
            <div className="mt-4 flex flex-wrap items-center gap-3">
              <button
                type="button"
                onClick={() => reset()}
                className="rounded-lg bg-brand px-3.5 py-2 text-sm font-medium text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              >
                Réessayer
              </button>
              {/* Lien natif (et non next/link) : le routeur de Next peut être celui qui est en panne. */}
              <a
                href="/"
                className="rounded-lg px-2 py-2 text-sm font-medium text-brand underline-offset-2 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              >
                Retour à l&apos;accueil
              </a>
            </div>
          </div>
        </main>
      </body>
    </html>
  );
}
