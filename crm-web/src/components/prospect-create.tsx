'use client';

import { useActionState, useState } from 'react';
import { Plus, X } from 'lucide-react';
import { createProspect, type ProspectFormState } from '@/lib/prospect-actions';
import type { ProspectStatut } from '@/lib/api';
import { STATUT_LABELS, SOURCE_LABELS } from './prospect-badges';

const INITIAL: ProspectFormState = { error: null };
const SOURCES = Object.keys(SOURCE_LABELS) as (keyof typeof SOURCE_LABELS)[];
const STATUTS = Object.keys(STATUT_LABELS) as ProspectStatut[];

const field =
  'w-full rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand focus:ring-2 focus:ring-brand/30 dark:border-navy-700 dark:bg-navy-950';
const labelCls = 'text-xs font-medium text-neutral-500';

/**
 * Bouton + formulaire de création de prospect (POST /prospects). À ne proposer qu'aux rôles qui peuvent créer
 * (voir PROSPECTS_ECRITURE) ; `secteurs` vient de GET /prospects/secteurs (le périmètre du rôle).
 * `secteursIndisponibles` : la liste n'a pas pu être chargée (le prospect serait créé sans secteur).
 */
export function ProspectCreate({
  secteurs,
  secteursIndisponibles = false,
}: {
  secteurs: { id: string; code: string; nom: string }[];
  secteursIndisponibles?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(createProspect, INITIAL);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Plus size={15} /> Nouveau prospect
      </button>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-16">
      <div className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-xl dark:bg-navy-900">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold">Nouveau prospect</h2>
          <button type="button" onClick={() => setOpen(false)} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form action={action} className="flex flex-col gap-3">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <label className="flex flex-col gap-1 sm:col-span-2">
              <span className={labelCls}>Enseigne *</span>
              <input name="enseigne" required maxLength={200} placeholder="Carrefour Contact Lunel" className={field} />
            </label>
            <label className="flex flex-col gap-1 sm:col-span-2">
              <span className={labelCls}>Raison sociale *</span>
              <input name="raisonSociale" required maxLength={200} placeholder="SUPERMARCHE DUPONT SAS" className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Ville</span>
              <input name="ville" maxLength={100} className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Code postal</span>
              <input name="codePostal" maxLength={10} className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Téléphone</span>
              <input name="telephone" maxLength={20} className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Email</span>
              <input name="email" type="email" maxLength={200} className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Secteur</span>
              {/* Un seul secteur proposable (cas d'un chef de secteur) : présélectionné, un prospect sans secteur
                  n'apparaît pas dans le pilotage par secteur. */}
              <select name="secteurId" defaultValue={secteurs.length === 1 ? secteurs[0].id : ''} className={field}>
                <option value="">— aucun —</option>
                {secteurs.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.nom} ({s.code})
                  </option>
                ))}
              </select>
              {secteursIndisponibles ? (
                <span role="status" className="text-[11px] text-amber-600">
                  Liste des secteurs indisponible : le prospect serait créé sans secteur.
                </span>
              ) : null}
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Source</span>
              <select name="source" defaultValue="" className={field}>
                <option value="">— non précisée —</option>
                {SOURCES.map((s) => (
                  <option key={s} value={s}>
                    {SOURCE_LABELS[s]}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Classe du client</span>
              <select name="niveauClass" defaultValue="" className={field}>
                <option value="">— non renseignée —</option>
                {(['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const).map((c) => (
                  <option key={c} value={c}>
                    Classe {c}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Étape</span>
              <select name="statut" defaultValue="NOUVEAU" className={field}>
                {STATUTS.map((s) => (
                  <option key={s} value={s}>
                    {STATUT_LABELS[s]}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Probabilité (%)</span>
              <input name="probabilite" type="number" min="0" max="100" className={field} />
            </label>
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Potentiel CA/an (€)</span>
              <input name="potentielCaAnnuel" type="number" min="0" step="1000" className={field} />
            </label>
          </div>

          {state.error ? <p role="alert" className="text-sm text-red-700">{state.error}</p> : null}

          <div className="mt-1 flex justify-end gap-2">
            <button type="button" onClick={() => setOpen(false)} className="rounded-lg px-3 py-2 text-sm text-neutral-500 hover:text-neutral-700">
              Annuler
            </button>
            <button
              type="submit"
              disabled={pending}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-4 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
            >
              <Plus size={15} /> {pending ? 'Création…' : 'Créer le prospect'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
