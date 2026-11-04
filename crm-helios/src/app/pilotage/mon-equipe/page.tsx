import { redirect } from 'next/navigation';
import { Users } from 'lucide-react';
import { getMe } from '@/lib/api';
import { cartesChefs, lignesPromoteurs, listerUtilisateurs } from '@/lib/equipe';
import { CARTE, ListePromoteurs } from '@/components/equipe-ui';
import { EquipeDrBoard } from '@/components/equipe-dr-board';

export const metadata = { title: 'Mon équipe — Direction commerciale' };

// Chef de secteur : ses promoteurs. Directeur régional (et ADMIN, vue technique) : ses chefs de secteur ou ses promoteurs.
const ROLES_AUTORISES = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN'];

function Indisponible() {
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold">Mon équipe</h1>
      <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Équipe indisponible — l&apos;API est-elle démarrée ?
      </p>
    </div>
  );
}

export default async function MonEquipePage() {
  const me = await getMe();
  if (!me) redirect('/login');
  if (!ROLES_AUTORISES.includes(me.role)) redirect('/pilotage');

  // L'API restreint déjà la liste au périmètre du rôle ; on ne garde ici que ce qu'on présente.
  const users = await listerUtilisateurs();
  if (!users) return <Indisponible />;
  const chefs = users.filter((u) => u.role === 'CHEF_SECTEUR' && u.isActive);
  const promoteurs = users.filter((u) => u.role === 'COMMERCIAL' && u.isActive);

  // --- Chef de secteur : liste des promoteurs de son secteur ---
  if (me.role === 'CHEF_SECTEUR') {
    const promos = (await lignesPromoteurs(promoteurs, chefs)).sort((a, b) => a.nom.localeCompare(b.nom));
    return (
      <div className="flex flex-col gap-5">
        <div>
          <h1 className="text-2xl font-bold">Mon équipe</h1>
          <p className="text-sm text-neutral-500">
            {promos.length} promoteur{promos.length > 1 ? 's' : ''}
            {users.find((u) => u.id === me.id)?.secteur ? ` · ${users.find((u) => u.id === me.id)!.secteur!.nom}` : ''}
          </p>
        </div>
        <ListePromoteurs promos={promos} vide="Aucun promoteur dans votre secteur." />
        <p className="text-center text-xs text-neutral-400">Touchez un promoteur pour voir ses visites, ses commandes et son planning.</p>
      </div>
    );
  }

  // --- Directeur régional / administrateur ---
  if (chefs.length === 0 && promoteurs.length === 0) {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl font-bold">Mon équipe</h1>
        <div className={`${CARTE} p-10 text-center`}>
          <Users size={32} className="mx-auto text-accent" aria-hidden />
          <p className="mt-3 font-medium">Aucun chef de secteur ni promoteur dans votre périmètre.</p>
          <p className="mt-1 text-sm text-neutral-400">
            Les rattachements « directeur » sont synchronisés depuis l&apos;AD.
          </p>
        </div>
      </div>
    );
  }
  const promos = (await lignesPromoteurs(promoteurs, chefs)).sort((a, b) => a.nom.localeCompare(b.nom));
  const cartes = (await cartesChefs(chefs, promos)).sort((a, b) => a.nom.localeCompare(b.nom));
  return <EquipeDrBoard chefs={cartes} promos={promos} />;
}
