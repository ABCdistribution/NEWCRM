'use client';

import Link from 'next/link';
import { ClipboardCheck } from 'lucide-react';

/**
 * « Visite commerciale » depuis la fiche magasin : ouvre le questionnaire de
 * visite (checklist, remplissage linéaire, compte rendu) — l'enregistrement
 * crée la visite du magasin.
 */
export function MagasinTourneeButton({ clientId }: { clientId: string }) {
  return (
    <Link
      href={`/pilotage/magasins/${clientId}/visite`}
      className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
    >
      <ClipboardCheck size={13} /> Visite commerciale
    </Link>
  );
}
