'use client';

import { useState, useTransition } from 'react';
import { Save } from 'lucide-react';
import { majLivraison } from '@/lib/commande-actions';
import type { StatutLivraison } from '@/lib/api';
import { LIVRAISON } from './livraison-badge';

const STATUTS: StatutLivraison[] = ['EN_PREPARATION', 'EXPEDIEE', 'LIVREE_PARTIELLE', 'LIVREE'];

const input =
  'w-full rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm text-neutral-800 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-100';

/**
 * Formulaire de mise à jour du suivi de livraison — affiché aux rôles
 * ADV / DIRECTION / ADMIN sur la fiche commande.
 */
export function LivraisonEditor({
  commandeId,
  statut,
  transporteur,
  noSuivi,
  commentaire,
}: {
  commandeId: string;
  statut: StatutLivraison;
  transporteur: string | null;
  noSuivi: string | null;
  commentaire: string | null;
}) {
  const [form, setForm] = useState({
    statutLivraison: statut,
    transporteur: transporteur ?? '',
    noSuivi: noSuivi ?? '',
    commentaireLivraison: commentaire ?? '',
  });
  const [pending, start] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; texte: string } | null>(null);

  const enregistrer = () =>
    start(async () => {
      const erreur = await majLivraison(commandeId, form);
      setMessage(erreur ? { ok: false, texte: erreur } : { ok: true, texte: 'Suivi enregistré.' });
    });

  return (
    <div className="flex flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          Statut
          <select
            value={form.statutLivraison}
            onChange={(e) => setForm((f) => ({ ...f, statutLivraison: e.target.value as StatutLivraison }))}
            className={input}
          >
            {STATUTS.map((s) => (
              <option key={s} value={s}>
                {LIVRAISON[s].label}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          Transporteur
          <input
            value={form.transporteur}
            onChange={(e) => setForm((f) => ({ ...f, transporteur: e.target.value }))}
            placeholder="GLS, DPD, affrètement…"
            className={input}
          />
        </label>
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500">
          N° de suivi
          <input
            value={form.noSuivi}
            onChange={(e) => setForm((f) => ({ ...f, noSuivi: e.target.value }))}
            placeholder="Référence transporteur"
            className={input}
          />
        </label>
        <label className="flex flex-col gap-1 text-xs font-medium text-neutral-500 sm:col-span-2">
          Commentaire
          <input
            value={form.commentaireLivraison}
            onChange={(e) => setForm((f) => ({ ...f, commentaireLivraison: e.target.value }))}
            placeholder="Litige, reliquat, point relais…"
            className={input}
          />
        </label>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={enregistrer}
          disabled={pending}
          className="inline-flex items-center gap-2 rounded-lg bg-brand px-3 py-1.5 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50 dark:bg-accent dark:text-brand"
        >
          <Save size={14} />
          {pending ? 'Enregistrement…' : 'Enregistrer'}
        </button>
        {message ? (
          <p className={`text-xs ${message.ok ? 'text-emerald-600' : 'text-red-500'}`}>{message.texte}</p>
        ) : null}
      </div>
    </div>
  );
}
