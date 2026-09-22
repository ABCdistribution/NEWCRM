import { redirect } from 'next/navigation';
import { getMe } from '@/lib/api';
import { ComingSoon } from '@/components/coming-soon';

export const metadata = { title: 'Paramètres — Selios' };

export default async function ParametresPage() {
  const me = await getMe();
  if (!me) redirect('/login');
  if (me.role !== 'ADMIN') {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-400">
        <h1 className="text-lg font-semibold">Accès refusé</h1>
        <p className="mt-1 text-sm">Cette page est réservée aux administrateurs.</p>
      </div>
    );
  }

  return (
    <ComingSoon
      title="Paramètres"
      description="Configuration de l'application (rôles, mappings, préférences)."
    />
  );
}
