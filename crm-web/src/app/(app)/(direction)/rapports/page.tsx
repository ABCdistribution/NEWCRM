import { listRapports } from '@/lib/api';
import { requireRole } from '@/lib/roles';
import { iso, lundiDemande } from '@/lib/equipe-utils';
import { RapportsBoard } from '@/components/rapports-board';

export const metadata = { title: 'Rapports d’activité — Direction commerciale' };

// Exclut CHEF_SECTEUR (même règle que routes.ts).
const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'] as const;

export default async function RapportsPage({ searchParams }: { searchParams: Promise<{ semaine?: string }> }) {
  const acces = await requireRole(ALLOWED);
  if (acces.refuse) return acces.refuse;

  const sp = await searchParams;
  // lundiDemande ignore une date impossible (?semaine=2026-13-45) et retombe sur la semaine courante.
  const semaine = iso(lundiDemande(sp.semaine));
  const data = await listRapports(semaine);
  return <RapportsBoard data={data} semaine={semaine} nonDisponible={data === null} />;
}
