import { notFound } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { getClient, idSur } from '@/lib/api';
import { ENCADREMENT, requireRole } from '@/lib/roles';
import { VisiteCommercialeForm } from '@/components/visite-commerciale-form';

export const metadata = { title: 'Visite commerciale' };

/** Questionnaire de visite commerciale d'un client — encadrement uniquement. */
export default async function VisiteCommercialePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const acces = await requireRole(ENCADREMENT);
  if (acces.refuse) return acces.refuse;

  const { id: idBrut } = await params;
  const id = idSur(idBrut);
  const client = await getClient(id);
  if (!client) notFound();

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <div className="flex items-center gap-3">
        <Link
          href={`/clients/${encodeURIComponent(client.id)}`}
          className="rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:border-navy-700 dark:hover:bg-navy-800 dark:focus-visible:outline-accent"
          aria-label="Retour à la fiche client"
        >
          <ArrowLeft size={16} />
        </Link>
        <div>
          <h1 className="text-2xl font-bold">Visite commerciale</h1>
          <p className="text-sm text-neutral-400">
            {client.enseigne} · {[client.codePostal, client.ville].filter(Boolean).join(' ')} · code {client.codeAs400}
          </p>
        </div>
      </div>

      <VisiteCommercialeForm clientId={client.id} enseigne={client.enseigne} />
    </div>
  );
}
