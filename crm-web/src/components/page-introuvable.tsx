import Link from 'next/link';
import { SearchX } from 'lucide-react';

/** Contenu de la page « introuvable » (404), commun à l'application connectée et à la racine. */
export function PageIntrouvable() {
  return (
    <div className="mx-auto max-w-md rounded-xl border border-neutral-200 bg-white p-6 text-neutral-800 shadow-sm">
      <h1 className="flex items-center gap-2 text-lg font-semibold">
        <SearchX size={20} aria-hidden />
        Page introuvable
      </h1>
      <p className="mt-2 text-sm text-neutral-600">
        Cette page n'existe pas, l'élément demandé n'existe plus ou n'est pas dans votre périmètre.
      </p>
      <Link
        href="/"
        className="mt-4 inline-flex rounded-lg bg-brand px-3.5 py-2 text-sm font-medium text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        Retour à l'accueil
      </Link>
    </div>
  );
}
