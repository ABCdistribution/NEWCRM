'use client';

import { useState, useTransition } from 'react';
import { Mail, PhoneCall } from 'lucide-react';
import { lienMailto, lienTel } from '@/lib/contact-liens';
import { logAppelFiche, logEmailFiche } from '@/lib/prospect-actions';

// Même recette que les boutons d'action pleins de l'app (ex. « Synchroniser depuis l'AD ») :
// fond de marque + texte blanc — lisible quel que soit le fond de la page.
const btn =
  'inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80';

/**
 * Actions de contact de la fiche prospect : lance l'appel (tel:) ou le mail (mailto:)
 * ET journalise l'interaction dans la timeline du prospect.
 */
export function ProspectContactActions({
  prospectId,
  telephone,
  email,
}: {
  prospectId: string;
  telephone: string | null;
  email: string | null;
}) {
  const [pending, startTransition] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  // Liens validés (contact-liens.ts) : une valeur mal formée ne produit aucun lien.
  const lienAppel = lienTel(telephone);
  const lienMail = lienMailto(email);

  const appeler = () => {
    if (!lienAppel) return;
    // Le softphone / mobile prend la main ; la journalisation part en parallèle.
    window.location.href = lienAppel;
    startTransition(async () => {
      const r = await logAppelFiche(prospectId);
      setErreur(r.error ? `Appel non journalisé : ${r.error}` : null);
    });
  };

  const envoyerMail = () => {
    if (!lienMail) return;
    window.location.href = lienMail;
    // Le journal reçoit l'adresse lue sur la fiche par le serveur, pas une valeur envoyée par le navigateur.
    startTransition(async () => {
      const r = await logEmailFiche(prospectId);
      setErreur(r.error ? `Email non journalisé : ${r.error}` : null);
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
            ? `Appeler ${telephone} (journalisé dans la timeline)`
            : telephone
              ? 'Numéro de téléphone invalide'
              : 'Pas de numéro de téléphone'
        }
        className={btn}
      >
        <PhoneCall size={13} aria-hidden /> Appeler
      </button>
      <button
        type="button"
        onClick={envoyerMail}
        disabled={!lienMail || pending}
        title={
          lienMail
            ? `Écrire à ${email} (journalisé dans la timeline)`
            : email
              ? 'Adresse email invalide'
              : "Pas d'adresse email"
        }
        className={btn}
      >
        <Mail size={13} aria-hidden /> Envoyer un mail
      </button>
      {erreur ? (
        <span role="alert" className="text-xs text-red-700">
          {erreur}
        </span>
      ) : null}
    </div>
  );
}
