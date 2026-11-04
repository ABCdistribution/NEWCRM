import Link from 'next/link';
import { ArrowLeft, Mail, Phone } from 'lucide-react';
import { Avatar } from './avatar';
import { BOUTON_LIEN, FOCUS, initiales } from './equipe-ui';

/**
 * En-tête d'une fiche d'équipe : retour, nom, sous-titre, « Envoyer un mail » (mailto) et « Appeler ».
 * Le modèle User n'a pas de téléphone : « Appeler » reste désactivé tant que l'API n'expose pas de numéro.
 */
export function FicheEntete({
  nom,
  sousTitre,
  retourHref,
  retourLabel,
  email,
  children,
}: {
  nom: string;
  sousTitre: string;
  retourHref: string;
  retourLabel: string;
  email: string | null;
  children?: React.ReactNode;
}) {
  const desactive = 'inline-flex cursor-not-allowed items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-300 dark:border-navy-700 dark:text-neutral-600';
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div className="flex min-w-0 items-center gap-3">
        <Link
          href={retourHref}
          className={`rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800 ${FOCUS}`}
          aria-label={retourLabel}
        >
          <ArrowLeft size={16} />
        </Link>
        <Avatar initials={initiales(nom)} size={44} />
        <div className="min-w-0">
          <h1 className="truncate text-2xl font-bold">{nom}</h1>
          <p className="truncate text-sm text-neutral-500">{sousTitre}</p>
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {children}
        {email ? (
          <a href={`mailto:${email}`} className={BOUTON_LIEN}>
            <Mail size={15} aria-hidden /> Envoyer un mail
          </a>
        ) : (
          <span className={desactive} title="Adresse e-mail non disponible" aria-disabled="true">
            <Mail size={15} aria-hidden /> Envoyer un mail
          </span>
        )}
        <span className={desactive} title="Numéro non disponible" aria-disabled="true" role="button" tabIndex={0}>
          <Phone size={15} aria-hidden /> Appeler
        </span>
      </div>
    </div>
  );
}
