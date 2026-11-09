import { redirect } from 'next/navigation';
import { getMe, getNotifications } from '@/lib/api';
import { espaceDe } from '@/lib/roles';
import { construireMenu } from '@/lib/menu';
import { SideMenu } from '@/components/side-menu';

/**
 * Layout de toute l'application connectée. Pas de session valide → /login.
 * Le thème (bleu / violet) suit le RÔLE, pas le groupe de routes : l'encadrement ouvre aussi
 * les écrans terrain et garde son thème violet.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe();
  if (!me) redirect('/login');

  const espace = espaceDe(me.role);
  // Cloche de notifications : COMMERCIAL uniquement.
  const notifications = me.role === 'COMMERCIAL' ? ((await getNotifications()) ?? { nonLues: 0, items: [] }) : null;

  return (
    // Mobile : barre hamburger au-dessus du contenu ; ≥ md : sidebar + contenu côte à côte.
    <div data-espace={espace} className="min-h-screen md:flex">
      <SideMenu me={me} espace={espace} sections={construireMenu(me.role, espace)} notifications={notifications} />
      <main className="min-w-0 flex-1">
        <div className="mx-auto max-w-[88rem] px-4 py-4 sm:px-6 sm:py-6">{children}</div>
      </main>
    </div>
  );
}
