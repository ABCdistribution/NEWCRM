import { Users } from 'lucide-react';
import { getMe, listUsers, getDashboardDirection, type UserRow, type DashboardDirection } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { MonEquipeBoard, type Membre } from '@/components/mon-equipe-board';

export const metadata = { title: 'Mon équipe — Helios' };

const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'];

export default async function MonEquipePage() {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;

  const now = new Date();
  const data = await getDashboardDirection(now.getFullYear(), now.getMonth() + 1);

  // Récupère tous les utilisateurs par pages de 20 (l'API plafonne `limit`).
  const users: UserRow[] = [];
  let apiOk = false;
  try {
    for (let p = 1; p <= 20; p++) {
      const res = await listUsers({ page: p, limit: 20 });
      apiOk = true;
      users.push(...res.data);
      if (users.length >= res.total || res.data.length < 20) break;
    }
  } catch {
    apiOk = false;
  }

  if (!apiOk) {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl font-bold">Mon équipe</h1>
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Équipe indisponible — l&apos;API est-elle démarrée ?
        </p>
      </div>
    );
  }

  // Perf par code représentant (classement du mois).
  const perf = new Map<string, DashboardDirection['classement'][number]>();
  for (const p of data?.classement ?? []) if (p.idRepr) perf.set(p.idRepr, p);

  // Collaborateurs directs, enrichis de leur performance.
  const team: Membre[] = users
    .filter((u) => u.directeur?.id === me.id)
    .map((u) => {
      const p = u.idRepr ? perf.get(u.idRepr) : undefined;
      return {
        id: u.id,
        displayName: u.displayName,
        username: u.username,
        role: u.role,
        isActive: u.isActive,
        idRepr: u.idRepr,
        secteur: u.secteur,
        region: u.region,
        ca: p?.ca ?? null,
        deltaPct: p?.deltaPct ?? null,
        tauxPct: p?.tauxPct ?? null,
      };
    });

  if (team.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl font-bold">Mon équipe</h1>
        <div className="rounded-2xl bg-white p-10 text-center shadow-card">
          <Users size={32} className="mx-auto text-[#A78BDA]" />
          <p className="mt-3 font-medium">Aucun collaborateur rattaché.</p>
          <p className="mt-1 text-sm text-neutral-400">
            Les rattachements « directeur » sont synchronisés depuis l&apos;AD. Aucun utilisateur ne vous a
            pour directeur pour le moment.
          </p>
        </div>
      </div>
    );
  }

  return <MonEquipeBoard team={team} meName={me.displayName} />;
}
