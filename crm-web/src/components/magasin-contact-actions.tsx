'use client';

import { useState, useTransition } from 'react';
import { Mail, PhoneCall } from 'lucide-react';
import { lienMailto, lienTel } from '@/lib/contact-liens';
import { logAppelMagasin, logEmailMagasin } from '@/lib/magasin-actions';

// Même recette que les boutons de contact de la fiche prospect :
// fond de marque + texte blanc — lisible quel que soit le fond.
const btn =
  'inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent disabled:cursor-not-allowed disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80';

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
  const [erreur, setErreur] = useState<string | null>(null);

  // Liens validés (contact-liens.ts) : une valeur d'import mal formée ne produit aucun lien.
  const lienAppel = lienTel(telephone);
  const lienMail = lienMailto(email);

  const appeler = () => {
    if (!lienAppel) return;
    window.location.href = lienAppel;
    startTransition(async () => {
      setErreur((await logAppelMagasin(clientId)).error);
    });
  };

  const envoyerMail = () => {
    if (!lienMail) return;
    window.location.href = lienMail;
    // Le journal reçoit l'adresse lue sur la fiche par le serveur, pas une valeur envoyée par le navigateur.
    startTransition(async () => {
      setErreur((await logEmailMagasin(clientId)).error);
    });
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      <button
        type="button"
        onClick={appeler}
        disabled={!lienAppel || pending}
        title={
          lienAppel
            ? `Appeler ${telephone} (journalisé)`
            : telephone
              ? 'Numéro de téléphone invalide'
              : 'Pas de numéro de téléphone'
        }
        className={btn}
      >
        <PhoneCall size={13} /> Appeler
      </button>
      <button
        type="button"
        onClick={envoyerMail}
        disabled={!lienMail || pending}
        title={
          lienMail ? `Écrire à ${email} (journalisé)` : email ? 'Adresse email invalide' : "Pas d'adresse email"
        }
        className={btn}
      >
        <Mail size={13} /> Envoyer un mail
      </button>
      {erreur ? (
        <p role="alert" className="w-full text-xs text-red-600 dark:text-red-400">
          Journalisation impossible : {erreur}
        </p>
      ) : null}
    </div>
  );
}
