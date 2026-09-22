'use client';

import { useState, useTransition } from 'react';
import { Check, Mail, MapPin, Pencil, Phone, X } from 'lucide-react';
import { updateCoordonneesFiche } from '@/lib/prospect-actions';

type Coords = {
  adresse1: string | null;
  codePostal: string | null;
  ville: string | null;
  telephone: string | null;
  email: string | null;
};

const champ =
  'w-full rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950';

/**
 * Coordonnées de la fiche prospect, éditables après création : le crayon passe
 * la carte en mode formulaire (adresse, CP, ville, téléphone, email).
 */
export function ProspectCoordonnees({ prospectId, coords }: { prospectId: string; coords: Coords }) {
  const [edition, setEdition] = useState(false);
  const [form, setForm] = useState({
    adresse1: coords.adresse1 ?? '',
    codePostal: coords.codePostal ?? '',
    ville: coords.ville ?? '',
    telephone: coords.telephone ?? '',
    email: coords.email ?? '',
  });
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));

  const enregistrer = () => {
    startTransition(async () => {
      const { error } = await updateCoordonneesFiche(prospectId, form);
      if (error) setErreur(error);
      else {
        setErreur(null);
        setEdition(false);
      }
    });
  };

  if (!edition) {
    return (
      <div className="flex flex-col gap-4">
        <Ligne icon={MapPin} label="Adresse" valeur={[coords.adresse1, [coords.codePostal, coords.ville].filter(Boolean).join(' ')].filter(Boolean).join(', ') || '—'} />
        <Ligne icon={Phone} label="Téléphone" valeur={coords.telephone ?? '—'} />
        <Ligne icon={Mail} label="Email" valeur={coords.email ?? '—'} />
        <button
          type="button"
          onClick={() => setEdition(true)}
          className="inline-flex w-fit items-center gap-1.5 rounded-lg border border-neutral-200 px-2.5 py-1.5 text-xs font-medium text-neutral-500 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:hover:border-accent dark:hover:text-accent"
        >
          <Pencil size={12} /> Modifier les coordonnées
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2.5">
      <input placeholder="Adresse" value={form.adresse1} onChange={set('adresse1')} className={champ} />
      <div className="flex gap-2">
        <input placeholder="Code postal" value={form.codePostal} onChange={set('codePostal')} className={`${champ} w-28`} />
        <input placeholder="Ville" value={form.ville} onChange={set('ville')} className={champ} />
      </div>
      <input placeholder="Téléphone" type="tel" value={form.telephone} onChange={set('telephone')} className={champ} />
      <input placeholder="Email" type="email" value={form.email} onChange={set('email')} className={champ} />
      {erreur ? <p className="text-xs text-red-500">{erreur}</p> : null}
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={enregistrer}
          disabled={pending}
          className="inline-flex items-center gap-1.5 rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
        >
          <Check size={13} /> Enregistrer
        </button>
        <button
          type="button"
          onClick={() => setEdition(false)}
          className="inline-flex items-center gap-1 text-xs text-neutral-400 underline underline-offset-2"
        >
          <X size={12} /> annuler
        </button>
      </div>
    </div>
  );
}

function Ligne({ icon: Icon, label, valeur }: { icon: typeof MapPin; label: string; valeur: string }) {
  return (
    <div className="flex items-start gap-2.5">
      <Icon size={15} className="mt-0.5 shrink-0 text-[#7D8CCE]" />
      <div className="min-w-0">
        <p className="text-xs text-neutral-400">{label}</p>
        <p className="text-sm font-medium">{valeur}</p>
      </div>
    </div>
  );
}
