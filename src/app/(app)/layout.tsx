import { redirect } from 'next/navigation';
import { ShieldX } from 'lucide-react';
import { getMe } from '@/lib/api';
import { logout } from '@/lib/auth-actions';
import { SideMenu } from '@/components/side-menu';

/** Rôles autorisés sur helios (portail de pilotage). */
const ALLOWED_ROLES = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADMIN'];

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe();
  if (!me) redirect('/login');

  // helios est réservé à l'encadrement : un commercial est renvoyé vers kratos.
  if (!ALLOWED_ROLES.includes(me.role)) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-white px-6">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 text-center shadow-card">
          <ShieldX size={36} className="mx-auto text-brand dark:text-accent" />
          <h1 className="mt-4 text-xl font-bold">Accès réservé</h1>
          <p className="mt-2 text-sm text-neutral-400">
            Helios est le portail de pilotage, réservé à l&apos;encadrement (chef de secteur et
            au-dessus). Ton espace de travail est <strong>kratos</strong>.
          </p>
          <div className="mt-6 flex justify-center gap-3">
            <a
              href="http://localhost:3000"
              className="rounded-xl bg-brand px-4 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
            >
              Aller sur kratos
            </a>
            <form action={logout}>
              <button
                type="submit"
                className="rounded-lg border border-neutral-200 px-4 py-2 text-sm text-neutral-400 transition hover:text-red-500 dark:border-navy-700"
              >
                Déconnexion
              </button>
            </form>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <SideMenu me={me} />
      <main className="min-w-0 flex-1">
        <div className="mx-auto max-w-[1400px] px-6 py-6">{children}</div>
      </main>
    </div>
  );
}
