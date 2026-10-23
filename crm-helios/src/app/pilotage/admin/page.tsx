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
      <div>
        <h1 className="text-2xl font-bold">Administration</h1>
        <p className="text-sm text-neutral-500">Comptes, organisation, synchronisations et contenus d&apos;ABC Pilot et d&apos;ABC Sales.</p>
      </div>
      <AdminOnglets actif={onglet} />
      {contenu}
    </div>
  );
}
