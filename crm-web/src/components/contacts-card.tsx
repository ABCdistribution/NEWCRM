'use client';

import { useActionState, useEffect, useState } from 'react';
import { Users, Phone, Mail, Plus, Pencil, Trash2, X } from 'lucide-react';
import { saveContact, deleteContact, type ContactFormState } from '@/lib/client-actions';

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
        <input name="prenom" placeholder="Prénom" defaultValue={contact?.prenom ?? ''} className={input} />
        <input name="nom" placeholder="Nom *" required defaultValue={contact?.nom ?? ''} className={input} />
      </div>
      <div className="grid grid-cols-2 gap-2.5">
        <select name="typePoste" defaultValue={contact?.typePoste ?? ''} className={input}>
          <option value="">Type de poste…</option>
          {TYPE_POSTES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
        <input name="poste" placeholder="Précision poste" defaultValue={contact?.poste ?? ''} className={input} />
      </div>
      <div className="grid grid-cols-2 gap-2.5">
        <input name="portable" placeholder="Portable" defaultValue={contact?.portable ?? ''} className={input} />
        <input name="fixe" placeholder="Fixe" defaultValue={contact?.fixe ?? ''} className={input} />
      </div>
      <input name="mail" type="email" placeholder="Email" defaultValue={contact?.mail ?? ''} className={input} />

      {state.error ? <p className="text-xs text-red-600">{state.error}</p> : null}

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

export function ContactsCard({ clientId, contacts }: { clientId: string; contacts: ContactItem[] }) {
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
        <button
          type="button"
          onClick={() => setEditing(editing === 'new' ? null : 'new')}
          className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300"
        >
          {editing === 'new' ? <X size={13} /> : <Plus size={13} />}
          {editing === 'new' ? 'Fermer' : 'Ajouter'}
        </button>
      </h2>

      {editing === 'new' ? (
        <ContactForm clientId={clientId} contact={null} onClose={() => setEditing(null)} />
      ) : null}

      {contacts.length === 0 && editing !== 'new' ? (
        <p className="px-5 py-4 text-sm text-neutral-400">Aucun contact enregistré.</p>
      ) : (
        <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
          {contacts.map((c) =>
            editing === c.id ? (
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

                {/* Actions (visibles au survol) */}
                <div className="flex shrink-0 gap-1 opacity-0 transition group-hover:opacity-100">
                  <button
                    type="button"
                    onClick={() => setEditing(c.id)}
                    className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-brand dark:hover:bg-navy-800"
                    aria-label={`Modifier ${c.nom}`}
                  >
                    <Pencil size={14} />
                  </button>
                  <form
                    action={deleteContact}
                    onSubmit={(e) => {
                      if (!confirm(`Supprimer le contact ${[c.prenom, c.nom].filter(Boolean).join(' ')} ?`)) {
                        e.preventDefault();
                      }
                    }}
                  >
                    <input type="hidden" name="clientId" value={clientId} />
                    <input type="hidden" name="contactId" value={c.id} />
                    <button
                      type="submit"
                      className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/40"
                      aria-label={`Supprimer ${c.nom}`}
                    >
                      <Trash2 size={14} />
                    </button>
                  </form>
                </div>
              </li>
            ),
          )}
        </ul>
      )}
    </div>
  );
}
