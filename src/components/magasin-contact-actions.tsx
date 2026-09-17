'use client';

import { useTransition } from 'react';
import { Mail, PhoneCall } from 'lucide-react';
import { logAppelMagasin, logEmailMagasin } from '@/lib/magasin-actions';

// Même recette que les boutons de contact de la fiche prospect :
// fond de marque + texte blanc — lisible quel que soit le fond.
const btn =
  'inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:cursor-not-allowed disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80';

/**
 * Actions de contact du magasin : lance l'appel (tel:) ou le mail (mailto:)
 * ET journalise l'interaction (journal de contacts du magasin).
 */
export function MagasinContactActions({
  clientId,
  telephone,
  email,
}: {
  clientId: string;
  telephone: string | null;
  email: string | null;
}) {
  const [pending, startTransition] = useTransition();

  const appeler = () => {
    window.location.href = `tel:${telephone}`;
    startTransition(async () => {
      await logAppelMagasin(clientId);
    });
  };

  const envoyerMail = () => {
    window.location.href = `mailto:${email}`;
    startTransition(async () => {
      await logEmailMagasin(clientId, email!);
    });
  };

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        onClick={appeler}
        disabled={!telephone || pending}
        title={telephone ? `Appeler ${telephone} (journalisé)` : 'Pas de numéro de téléphone'}
        className={btn}
      >
        <PhoneCall size={13} /> Appeler
      </button>
      <button
        type="button"
        onClick={envoyerMail}
        disabled={!email || pending}
        title={email ? `Écrire à ${email} (journalisé)` : "Pas d'adresse email"}
        className={btn}
      >
        <Mail size={13} /> Envoyer un mail
      </button>
    </div>
  );
}
