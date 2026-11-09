import { Construction } from 'lucide-react';

const PREVUS: Record<'mobile' | 'configuration' | 'journal', { titre: string; prevu: string[]; prerequis: string }> = {
  mobile: {
    titre: 'Supervision des téléphones',
    prevu: [
      'Appareils par promoteur : modèle, version de l’application, dernier contact',
      'Dernière synchronisation réussie, visites et commandes en attente, erreurs',
      'Indicateurs : en retard, version obsolète, en erreur',
    ],
    prerequis:
      "Nécessite que l'application mobile remonte son état à chaque synchronisation (aujourd'hui, seuls des identifiants d'idempotence sont envoyés).",
  },
  configuration: {
    titre: 'Configuration',
    prevu: [
      'Seuils des indicateurs (par exemple délai avant qu’un téléphone soit « en retard »)',
      'Périodicités de visite, version minimale de l’application',
      'Historique des changements de paramètres',
    ],
    prerequis: 'Nécessite une table de paramètres côté API, avec validation des valeurs.',
  },
  journal: {
    titre: "Journal d'audit",
    prevu: [
      'Qui a fait quoi : changement de rôle, désactivation, import ou synchro lancée',
      'Consultation filtrable par utilisateur, action et période',
    ],
    prerequis: "Nécessite d'enregistrer les opérations sensibles côté API.",
  },
};

export function AdminBientotOnglet({ onglet }: { onglet: 'mobile' | 'configuration' | 'journal' }) {
  const { titre, prevu, prerequis } = PREVUS[onglet];
  return (
    <section className="rounded-2xl border border-dashed border-neutral-300 bg-white p-8">
      <h2 className="flex items-center gap-2 text-base font-semibold">
        <Construction size={18} className="text-violet-600" aria-hidden />
        {titre} — à venir
      </h2>
      <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-neutral-600">
        {prevu.map((p) => (
          <li key={p}>{p}</li>
        ))}
      </ul>
      <p className="mt-4 rounded-lg bg-neutral-50 px-3 py-2 text-xs text-neutral-500">{prerequis}</p>
    </section>
  );
}
