import { notFound } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { getClient } from '@/lib/api';
import { VisiteCommercialeForm } from '@/components/visite-commerciale-form';

export const metadata = { title: 'Visite commerciale — Helios' };

export default async function VisiteCommercialePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const client = await getClient(id);
  if (!client) notFound();

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <div className="flex items-center gap-3">
        <Link
          href="/pilotage/magasins"
          className="rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800"
          aria-label="Retour aux magasins"
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
