'use client';

import { useState, useTransition } from 'react';
import { RefreshCw } from 'lucide-react';
import { majUtilisateur, lancerSyncAd, type SyncAdResult } from '@/lib/admin-actions';
import type { Role } from '@/lib/api';

// Vocabulaire métier ABC : le rôle technique COMMERCIAL s'affiche « Promoteur ».
const ROLES: { value: Role; label: string }[] = [
  { value: 'COMMERCIAL', label: 'Promoteur' },
  { value: 'CHEF_SECTEUR', label: 'Chef de secteur' },
  { value: 'DIRECTEUR_REGIONAL', label: 'Directeur régional' },
  { value: 'DIRECTION', label: 'Direction' },
  { value: 'ADV', label: 'ADV' },
  { value: 'MARKETING', label: 'Marketing' },
  { value: 'ADMIN', label: 'Admin' },
];

/** Sélecteur de rôle d'un utilisateur — PATCH immédiat, erreur affichée en dessous. */
export function RoleSelect({ userId, role, disabled }: { userId: string; role: Role; disabled?: boolean }) {
  const [pending, start] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  return (
    <div>
      <select
        value={role}
        disabled={disabled || pending}
        onChange={(e) =>
          start(async () => setErreur(await majUtilisateur(userId, { role: e.target.value as Role })))
        }
        className="rounded-lg border border-neutral-200 bg-white px-2 py-1 text-xs text-neutral-700 disabled:opacity-50 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-200"
      >
        {ROLES.map((r) => (
          <option key={r.value} value={r.value}>
            {r.label}
          </option>
        ))}
      </select>
      {erreur ? <p className="mt-1 text-[11px] text-red-500">{erreur}</p> : null}
    </div>
  );
}

/** Interrupteur actif/désactivé d'un compte. */
export function ActifToggle({ userId, actif, disabled }: { userId: string; actif: boolean; disabled?: boolean }) {
  const [pending, start] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  return (
    <div>
      <button
        type="button"
        disabled={disabled || pending}
        onClick={() => start(async () => setErreur(await majUtilisateur(userId, { isActive: !actif })))}
        className={`rounded-full px-2.5 py-0.5 text-xs font-medium transition disabled:opacity-50 ${
          actif
            ? 'bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20'
            : 'bg-red-500/10 text-red-600 hover:bg-red-500/20'
        }`}
        title={actif ? 'Cliquer pour désactiver le compte' : 'Cliquer pour réactiver le compte'}
      >
        {actif ? 'Actif' : 'Désactivé'}
      </button>
      {erreur ? <p className="mt-1 text-[11px] text-red-500">{erreur}</p> : null}
    </div>
  );
}

/** Bouton de synchronisation AD en masse, avec compte-rendu inline. */
export function SyncAdButton() {
  const [pending, start] = useTransition();
  const [resultat, setResultat] = useState<SyncAdResult | { erreur: string } | null>(null);

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        disabled={pending}
        onClick={() => start(async () => setResultat(await lancerSyncAd()))}
        className="inline-flex items-center gap-2 rounded-lg bg-brand px-3 py-1.5 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50 dark:bg-accent dark:text-brand"
      >
        <RefreshCw size={14} className={pending ? 'animate-spin' : ''} />
        {pending ? 'Synchronisation…' : "Synchroniser depuis l'AD"}
      </button>
      {resultat ? (
        'erreur' in resultat ? (
          <p className="text-xs text-red-500">{resultat.erreur}</p>
        ) : (
          <p className="text-right text-xs text-neutral-500">
            {resultat.lus} lus · {resultat.crees} créés · {resultat.maj} mis à jour
            {resultat.conflitsIdRepr.length > 0 ? ` · conflits code repr : ${resultat.conflitsIdRepr.join(', ')}` : ''}
          </p>
        )
      ) : null}
    </div>
  );
}
