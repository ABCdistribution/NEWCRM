'use client';

import { useState } from 'react';
import { Check, Clock, X } from 'lucide-react';

export type EtapeOptions = {
  date: string;
  heure: string; // '' = pas d'heure précise
  visiteSimple: boolean;
  accompagnement: boolean;
  rdv: boolean;
  soireeEtape: boolean;
  soireeLieu: string;
  soireeAdresse: string;
  note: string;
  /** Client ou lieu en texte libre (ligne libre du rapport). */
  libelle: string;
  /** Adresse de la ligne. */
  adresse: string;
};

/**
 * Qualification d'une ligne du rapport d'activité (reprise de l'outil historique) : client ou lieu, adresse, visite
 * simple / accompagnement promoteur, RDV, heure, soirée étape et observations.
 * `libre` : ligne sans magasin ni prospect de la liste, dont le client est saisi en texte (le serveur n'impose pas de
 * choisir dans la liste). Aucun champ n'est obligatoire hormis ce libellé d'une ligne libre ; le lieu et l'adresse
 * d'une soirée étape sont contrôlés à l'enregistrement de la prévision et à la validation du rapport.
 */
export function EtapeOptionsDialog({
  titre,
  dateInitiale,
  onConfirm,
  onClose,
  pending = false,
  initial,
  confirmLabel = 'Ajouter au planning',
  libre = false,
  adresseModifiable = true,
}: {
  titre: string;
  dateInitiale: string;
  onConfirm: (options: EtapeOptions) => void;
  onClose: () => void;
  pending?: boolean;
  /** Valeurs de départ (requalification d'une étape existante). */
  initial?: Partial<EtapeOptions>;
  confirmLabel?: string;
  libre?: boolean;
  adresseModifiable?: boolean;
}) {
  const [form, setForm] = useState<EtapeOptions>({
    date: dateInitiale,
    heure: '',
    visiteSimple: true,
    accompagnement: false,
    rdv: false,
    soireeEtape: false,
    soireeLieu: '',
    soireeAdresse: '',
    note: '',
    libelle: '',
    adresse: '',
    ...initial,
  });

  const caseCls = 'h-4 w-4 accent-[var(--color-brand)]';
  const ligne = 'flex cursor-pointer select-none items-center gap-2 text-sm';
  const champ =
    'w-full rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950';
  const libelleManquant = libre && !form.libelle.trim();

  return (
    <div className="fixed inset-0 z-[60] flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-24" onClick={onClose}>
      <div className="w-full max-w-md rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-neutral-100 px-5 py-3.5 dark:border-navy-700">
          <h2 className="text-sm font-bold">{titre}</h2>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
            <X size={17} />
          </button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-4">
          {/* Client ou lieu en texte libre */}
          {libre ? (
            <input
              type="text"
              value={form.libelle}
              onChange={(e) => setForm((f) => ({ ...f, libelle: e.target.value }))}
              placeholder="Client ou lieu"
              aria-label="Client ou lieu"
              maxLength={200}
              autoFocus
              className={champ}
            />
          ) : null}

          {/* Date + heure */}
          <div className="flex items-center gap-2">
            <input
              type="date"
              value={form.date}
              onChange={(e) => setForm((f) => ({ ...f, date: e.target.value }))}
              className="rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
              aria-label="Date de passage"
            />
            <Clock size={14} className="text-neutral-400" />
            <input
              type="time"
              value={form.heure}
              onChange={(e) => setForm((f) => ({ ...f, heure: e.target.value }))}
              className="rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
              aria-label="Heure (optionnelle)"
            />
          </div>

          {/* Adresse de la ligne */}
          {adresseModifiable ? (
            <input
              type="text"
              value={form.adresse}
              onChange={(e) => setForm((f) => ({ ...f, adresse: e.target.value }))}
              placeholder="Adresse"
              aria-label="Adresse"
              maxLength={300}
              className={champ}
            />
          ) : null}

          {/* Type de passage */}
          <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
            <label className={ligne}>
              <input
                type="checkbox"
                checked={form.visiteSimple}
                onChange={(e) => setForm((f) => ({ ...f, visiteSimple: e.target.checked, accompagnement: e.target.checked ? false : f.accompagnement }))}
                className={caseCls}
              />
              Visite simple
            </label>
            <label className={ligne}>
              <input
                type="checkbox"
                checked={form.accompagnement}
                onChange={(e) => setForm((f) => ({ ...f, accompagnement: e.target.checked, visiteSimple: e.target.checked ? false : f.visiteSimple }))}
                className={caseCls}
              />
              Accompagnement promoteur
            </label>
            <label className={ligne}>
              <input type="checkbox" checked={form.rdv} onChange={(e) => setForm((f) => ({ ...f, rdv: e.target.checked }))} className={caseCls} />
              RDV
            </label>
          </div>

          {/* Soirée étape */}
          <div className="flex items-center gap-4 text-sm">
            <span className="font-medium">Soirée étape</span>
            {([true, false] as const).map((v) => (
              <label key={String(v)} className={ligne}>
                <input
                  type="radio"
                  name="soiree-etape"
                  checked={form.soireeEtape === v}
                  onChange={() => setForm((f) => ({ ...f, soireeEtape: v }))}
                  className={caseCls}
                />
                {v ? 'Oui' : 'Non'}
              </label>
            ))}
          </div>

          {/* Soirée étape : où dormir (obligatoire à la prévision et à la validation) */}
          {form.soireeEtape ? (
            <div className="flex flex-col gap-2 rounded-xl border border-neutral-200 bg-neutral-50 p-2.5 dark:border-navy-700 dark:bg-navy-950/50">
              <input
                type="text"
                value={form.soireeLieu}
                onChange={(e) => setForm((f) => ({ ...f, soireeLieu: e.target.value }))}
                placeholder="Lieu de l'étape (ville, hôtel…)"
                className={champ}
              />
              <input
                type="text"
                value={form.soireeAdresse}
                onChange={(e) => setForm((f) => ({ ...f, soireeAdresse: e.target.value }))}
                placeholder="Adresse de l'étape"
                className={champ}
              />
              <p className="px-0.5 text-[10px] text-neutral-400">Lieu et adresse sont obligatoires pour enregistrer la prévision et valider le rapport.</p>
            </div>
          ) : null}

          {/* Observations */}
          <textarea
            value={form.note}
            onChange={(e) => setForm((f) => ({ ...f, note: e.target.value }))}
            rows={2}
            placeholder="Observations"
            className="w-full rounded-xl border border-neutral-200 px-3 py-2 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
          />
        </div>

        <div className="flex justify-end gap-2 border-t border-neutral-100 px-5 py-3.5 dark:border-navy-700">
          <button type="button" onClick={onClose} className="rounded-xl px-3 py-1.5 text-xs font-medium text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800">
            Annuler
          </button>
          <button
            type="button"
            disabled={pending || !form.date || libelleManquant}
            onClick={() => onConfirm(form)}
            className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-4 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
          >
            <Check size={13} /> {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
