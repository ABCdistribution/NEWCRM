'use client';

import { useRouter } from 'next/navigation';
import { CloudOff, RefreshCw } from 'lucide-react';

/**
 * Écran affiché quand l'API ne répond pas (arrêt, redémarrage, erreur serveur) : la session n'est PAS perdue,
 * l'utilisateur n'est donc pas renvoyé vers /login. « Réessayer » relit la page courante auprès du serveur.
 */
export function ServiceIndisponible() {
  const router = useRouter();

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-8">
      <div role="alert" className="w-full max-w-md rounded-xl border border-neutral-200 bg-white p-6 text-neutral-800 shadow-sm">
        <h1 className="flex items-center gap-2 text-lg font-semibold">
          <CloudOff size={20} aria-hidden />
          Service momentanément indisponible
        </h1>
        <p className="mt-2 text-sm text-neutral-600">
          Le serveur ne répond pas pour le moment. Ta session est conservée : réessaie dans un instant.
        </p>
        <button
          type="button"
          onClick={() => router.refresh()}
          className="mt-4 inline-flex items-center gap-2 rounded-lg bg-brand px-3.5 py-2 text-sm font-medium text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <RefreshCw size={14} aria-hidden />
          Réessayer
        </button>
      </div>
    </main>
  );
}
