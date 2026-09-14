import { redirect } from 'next/navigation';
import { headers } from 'next/headers';
import { getMe } from '@/lib/api';
import { SideMenu } from '@/components/side-menu';

const KRATOS_PORT = process.env.KRATOS_PORT ?? '3002';

/** Rôles autorisés sur helios (portail de pilotage). Les autres (COMMERCIAL, ADV) → Kratos. */
const ALLOWED_ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe();
  if (!me) redirect('/login');

  // helios est réservé à l'encadrement ; COMMERCIAL / ADV sont renvoyés vers kratos (même hôte).
  if (!ALLOWED_ROLES.includes(me.role)) {
    const host = (await headers()).get('host')?.split(':')[0] ?? 'localhost';
    redirect(`http://${host}:${KRATOS_PORT}`);
  }

  return (
    <div className="flex min-h-screen">
      <SideMenu me={me} kratosPort={KRATOS_PORT} />
      <main className="min-w-0 flex-1">
        <div className="mx-auto max-w-[1400px] px-6 py-6">{children}</div>
      </main>
    </div>
  );
}
