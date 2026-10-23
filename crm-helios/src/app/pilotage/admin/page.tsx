import { ShieldCheck } from 'lucide-react';
import { getMe, getAdminApercu, getAdminOrganisation } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { AdminOnglets, ongletValide } from '@/components/admin/onglets';
import { AdminApercuOnglet } from '@/components/admin/apercu';
import { AdminUtilisateursOnglet } from '@/components/admin/utilisateurs';
import { AdminOrganisationOnglet } from '@/components/admin/organisation';
import { AdminSynchrosOnglet } from '@/components/admin/synchros';
import { AdminContenusOnglet } from '@/components/admin/contenus';
import { AdminBientotOnglet } from '@/components/admin/bientot';

export const metadata = { title: 'Administration — ABC Pilot' };

const INDISPONIBLE = (
  <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
    Données indisponibles — l&apos;API est-elle démarrée ?
  </p>
);

export default async function AdminPage({
  searchParams,
}: {
  searchParams: Promise<{ onglet?: string; search?: string; page?: string }>;
}) {
  // Réservé aux ADMIN (l'API le vérifie aussi sur chaque route).
  const me = await getMe();
  if (me?.role !== 'ADMIN') return <AccesRefuse />;

  const sp = await searchParams;
  const onglet = ongletValide(sp.onglet);

  let contenu: React.ReactNode;
  switch (onglet) {
    case 'apercu': {
      const data = await getAdminApercu();
      contenu = data ? <AdminApercuOnglet data={data} /> : INDISPONIBLE;
      break;
    }
    case 'utilisateurs':
      contenu = <AdminUtilisateursOnglet search={sp.search ?? ''} page={Number(sp.page ?? '1') || 1} />;
      break;
    case 'organisation': {
      const data = await getAdminOrganisation();
      contenu = data ? <AdminOrganisationOnglet data={data} /> : INDISPONIBLE;
      break;
    }
    case 'synchros':
      contenu = await AdminSynchrosOnglet();
      break;
    case 'contenus':
      contenu = <AdminContenusOnglet />;
      break;
    default:
      contenu = <AdminBientotOnglet onglet={onglet} />;
  }

  return (
    <div className="flex flex-col gap-5">
      <header className="flex items-center gap-4 rounded-2xl bg-[#130D25] px-5 py-4 text-white shadow-card">
        <span className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand">
          <ShieldCheck size={24} aria-hidden />
        </span>
        <div className="min-w-0">
          <h1 className="text-xl font-bold leading-tight">Administration</h1>
          <p className="text-xs uppercase tracking-wider text-white/50">Console de gestion</p>
        </div>
        <span className="ml-auto rounded-md border border-white/20 px-2 py-1 text-[11px] font-semibold uppercase tracking-wider text-white/70">
          Accès administrateur
        </span>
      </header>
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[230px_minmax(0,1fr)]">
        <AdminOnglets actif={onglet} />
        <div className="min-w-0">{contenu}</div>
      </div>
    </div>
  );
}
