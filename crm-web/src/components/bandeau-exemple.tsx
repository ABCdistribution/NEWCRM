import { Info } from 'lucide-react';

/**
 * Bandeau « Données d'exemple » : à afficher en tête de tout écran qui montre des données FICTIVES (maquette), sans
 * quoi elles passent pour des données réelles. À retirer avec le jeu de données quand l'API fournira les vraies
 * (filtrées par rôle ET périmètre côté API).
 */
export function BandeauExemple({ children }: { children: React.ReactNode }) {
  return (
    <div role="note" className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
      <Info size={18} className="mt-0.5 shrink-0 text-amber-700" aria-hidden="true" />
      <p>
        <strong className="font-semibold">Données d&apos;exemple.</strong> {children}
      </p>
    </div>
  );
}
