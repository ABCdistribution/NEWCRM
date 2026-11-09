import { requireRole, espaceDe, TOUS_ROLES } from '@/lib/roles';

export default async function Accueil() {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;

  return (
    <div>
      <h1 className="text-2xl font-semibold">Accueil — en cours de migration</h1>
      <p className="mt-2 text-sm">
        Connecté en tant que {me.displayName} · rôle {me.role} · espace {espaceDe(me.role)}.
      </p>
    </div>
  );
}
