import { ShieldAlert } from 'lucide-react';

/** Écran affiché quand une page d'administration est ouverte sans le rôle ADMIN. */
export function AccesRefuse() {
  return (
    <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
      <h1 className="flex items-center gap-2 text-lg font-semibold">
        <ShieldAlert size={20} />
        Accès refusé
      </h1>
      <p className="mt-1 text-sm">
        L&apos;administration (utilisateurs, secteurs, imports) est réservée aux administrateurs.
      </p>
    </div>
  );
}
