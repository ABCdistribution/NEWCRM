import { redirect } from 'next/navigation';
import { getMe, getNotifications } from '@/lib/api';
import { SideMenu } from '@/components/side-menu';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe();
  if (!me) redirect('/login');
  const notifications = await getNotifications();

  return (
    // Mobile : barre hamburger au-dessus du contenu (flux normal) ; ≥ md : sidebar + contenu côte à côte.
    <div className="min-h-screen md:flex">
      <SideMenu me={me} notifications={notifications ?? { nonLues: 0, items: [] }} />
      <main className="min-w-0 flex-1">
        <div className="mx-auto max-w-[88rem] px-4 py-4 sm:px-6 sm:py-6">{children}</div>
      </main>
    </div>
  );
}
