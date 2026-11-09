'use client';

import { useActionState, useEffect, useState } from 'react';
import { Users, Phone, Mail, Plus, Pencil, Trash2, X } from 'lucide-react';
import { saveContact, deleteContact, type ContactFormState } from '@/lib/client-actions';
import { SuppressionForm } from './suppression-form';

export type ContactItem = {
  id: string;
  prenom: string | null;
  nom: string;
  poste: string | null;
  typePoste: string | null;
  fixe: string | null;
  portable: string | null;
  mail: string | null;
};

/** Nomenclature des types de poste (héritée du legacy). */
const TYPE_POSTES = [
  'PDG',
  'Directeur',
  'Chef de département',
  'Chef de rayon DPH',
  'Chef de rayon Textile',
  'Chef de rayon PEM',
  'Chef de rayon Accessoires Animaux',
  'Employé de rayon',
];

const input =
  'w-full rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';

const INITIAL: ContactFormState = { error: null, ok: false };

function ContactForm({
  clientId,
  contact,
  onClose,
}: {
  clientId: string;
  contact: ContactItem | null; // null = création
  onClose: () => void;
}) {
  const [state, action, pending] = useActionState(saveContact, INITIAL);

  // Ferme le formulaire une fois l'enregistrement confirmé.
  useEffect(() => {
    if (state.ok) onClose();
  }, [state.ok, onClose]);

  return (
    <form action={action} className="flex flex-col gap-2.5 border-t border-neutral-100 bg-neutral-50/60 px-5 py-4 dark:border-navy-700 dark:bg-navy-950/40">
      <input type="hidden" name="clientId" value={clientId} />
      {contact ? <input type="hidden" name="contactId" value={contact.id} /> : null}

      <div className="grid grid-cols-2 gap-2.5">
        <input name="prenom" placeholder="Prénom" aria-label="Prénom" maxLength={60} defaultValue={contact?.prenom ?? ''} className={input} />
        <input name="nom" placeholder="Nom *" aria-label="Nom" required maxLength={60} defaultValue={contact?.nom ?? ''} className={input} />
      </div>
      <div className="grid grid-cols-2 gap-2.5">
        <select name="typePoste" aria-label="Type de poste" defaultValue={contact?.typePoste ?? ''} className={input}>
          <option value="">Type de poste…</option>
          {TYPE_POSTES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
        <input name="poste" placeholder="Précision poste" aria-label="Précision sur le poste" maxLength={80} defaultValue={contact?.poste ?? ''} className={input} />
      </div>
      <div className="grid grid-cols-2 gap-2.5">
        <input name="portable" placeholder="Portable" aria-label="Portable" maxLength={20} defaultValue={contact?.portable ?? ''} className={input} />
        <input name="fixe" placeholder="Fixe" aria-label="Téléphone fixe" maxLength={20} defaultValue={contact?.fixe ?? ''} className={input} />
      </div>
      <input name="mail" type="email" placeholder="Email" aria-label="Adresse e-mail" defaultValue={contact?.mail ?? ''} className={input} />

      {state.error ? <p role="alert" className="text-xs text-red-700">{state.error}</p> : null}

      <div className="flex justify-end gap-2 pt-1">
        <button
          type="button"
          onClick={onClose}
          className="rounded-lg px-3 py-1.5 text-xs text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
        >
          Annuler
        </button>
        <button
          type="submit"
          disabled={pending}
          className="rounded-xl bg-brand px-3 py-1.5 text-xs font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80 disabled:opacity-50"
        >
          {pending ? 'Enregistrement…' : contact ? 'Enregistrer' : 'Ajouter le contact'}
        </button>
      </div>
    </form>
  );
}

/**
 * Contacts du magasin. `peutEditer` (rôles de EDITEURS_CLIENT, calculé par la page) masque les boutons
 * d'ajout, de modification et de suppression ; l'API et les Server Actions restent juges.
 */
export function ContactsCard({
  clientId,
  contacts,
  peutEditer,
}: {
  clientId: string;
  contacts: ContactItem[];
  peutEditer: boolean;
}) {
  // null = fermé · 'new' = création · id = édition de ce contact
  const [editing, setEditing] = useState<string | null>(null);

  return (
    <div className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
        <Users size={17} className="text-brand" />
        Contacts
        <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
          {contacts.length}
        </span>
        {peutEditer ? (
          <button
            type="button"
            onClick={() => setEditing(editing === 'new' ? null : 'new')}
            className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand dark:border-navy-700 dark:text-neutral-300 dark:focus-visible:outline-accent"
          >
            {editing === 'new' ? <X size={13} /> : <Plus size={13} />}
            {editing === 'new' ? 'Fermer' : 'Ajouter'}
          </button>
        ) : null}
      </h2>

      {peutEditer && editing === 'new' ? (
        <ContactForm clientId={clientId} contact={null} onClose={() => setEditing(null)} />
      ) : null}

      {contacts.length === 0 && !(peutEditer && editing === 'new') ? (
        <p className="px-5 py-4 text-sm text-neutral-400">Aucun contact enregistré.</p>
      ) : (
        <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
          {contacts.map((c) =>
            peutEditer && editing === c.id ? (
              <li key={c.id}>
                <ContactForm clientId={clientId} contact={c} onClose={() => setEditing(null)} />
              </li>
            ) : (
              <li key={c.id} className="group flex items-start gap-2 px-5 py-3">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">
                    {[c.prenom, c.nom].filter(Boolean).join(' ')}
                    {c.typePoste || c.poste ? (
                      <span className="ml-1.5 text-xs font-normal text-neutral-400">
                        {c.typePoste ?? c.poste}
                      </span>
                    ) : null}
                  </p>
                  <p className="mt-0.5 flex flex-wrap gap-x-3 text-xs text-neutral-500">
                    {c.portable ? (
                      <span className="inline-flex items-center gap-1">
                        <Phone size={11} /> {c.portable}
                      </span>
                    ) : null}
                    {c.fixe ? (
                      <span className="inline-flex items-center gap-1">
                        <Phone size={11} /> {c.fixe}
                      </span>
                    ) : null}
                    {c.mail ? (
                      <span className="inline-flex items-center gap-1">
                        <Mail size={11} /> {c.mail}
                      </span>
                    ) : null}
                  </p>
                </div>

                {/* Actions (révélées au survol ou au focus, toujours visibles sur écran tactile) : réservées aux rôles éditeurs */}
                {peutEditer ? (
                  <div className="flex shrink-0 gap-1 opacity-0 transition group-hover:opacity-100 focus-within:opacity-100 [@media(hover:none)]:opacity-100">
                    <button
                      type="button"
                      onClick={() => setEditing(c.id)}
                      className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-brand focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand dark:hover:bg-navy-800 dark:focus-visible:outline-accent"
                      aria-label={`Modifier ${c.nom}`}
                    >
                      <Pencil size={14} />
                    </button>
                    <SuppressionForm
                      action={deleteContact}
                      champs={{ clientId, contactId: c.id }}
                      confirmation={`Supprimer le contact ${[c.prenom, c.nom].filter(Boolean).join(' ')} ?`}
                      libelle={`Supprimer ${c.nom}`}
                    />
                  </div>
                ) : null}
              </li>
            ),
          )}
        </ul>
      )}
    </div>
  );
}
