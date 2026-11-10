import { ShieldAlert } from 'lucide-react';

/** Écran affiché quand une page est ouverte avec un rôle non autorisé. */
export function AccesRefuse({
  message = "Ta fonction ne te donne pas accès à cette page.",
}: {
  message?: string;
}) {
  return (
    <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
      <h1 className="flex items-center gap-2 text-lg font-semibold">
        <ShieldAlert size={20} />
        Accès refusé
      </h1>
      <p className="mt-1 text-sm">{message}</p>
    </div>
  );
}
