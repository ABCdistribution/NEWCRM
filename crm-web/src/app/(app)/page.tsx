import Link from 'next/link';
import { Newspaper } from 'lucide-react';
import { estEncadrement, requireRole, TERRAIN, TOUS_ROLES } from '@/lib/roles';
import { DashboardDirection } from '@/components/dashboard-direction';
import { DashboardTerrain } from '@/components/dashboard-terrain';
import { aujourdhuiParis } from '@/lib/planning-dates';

export const metadata = { title: 'Accueil — SalesPilot ABC' };

/**
 * Entier lu dans l'URL (?annee=, ?mois=) : seule une suite de chiffres comprise entre `min` et `max`
 * est acceptée. Toute autre valeur (texte, décimal, signe, paramètre répété, hors bornes) est ignorée
 * (undefined) : la page retombe alors sur la date du jour.
 */
function entierBorne(brut: string | string[] | undefined, min: number, max: number): number | undefined {
  if (typeof brut !== 'string' || !/^\d{1,4}$/.test(brut)) return undefined;
  const n = Number(brut);
  return n >= min && n <= max ? n : undefined;
}

/**
 * Accueil des rôles sans tableau de bord défini (MARKETING : à définir, rien d'inventé) :
 * un bonjour et un lien vers Les News.
 */
function AccueilSimple({ prenom }: { prenom: string }) {
  return (
    <div className="flex flex-col gap-5">
      <h1 className="text-2xl font-bold">{prenom ? `Bonjour ${prenom}` : 'Bonjour'}</h1>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Link
          href="/news"
          className="flex items-center gap-3.5 rounded-2xl bg-white p-5 shadow-card transition hover:bg-neutral-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand/10">
            <Newspaper size={20} className="text-brand" aria-hidden />
          </span>
          <span className="min-w-0">
            <span className="block font-semibold">Les News</span>
            <span className="block text-sm text-neutral-500">Bienvenue sur SalesPilot ABC.</span>
          </span>
        </Link>
      </div>
    </div>
  );
}

/**
 * Accueil, une seule URL (/) pour tous les rôles : le contenu dépend de `me.role`.
 *  - encadrement (ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR) : pilotage de la force de vente ;
 *  - terrain (COMMERCIAL, ADV) : « Mes performances » ;
 *  - autre rôle (MARKETING) : petite carte d'accueil.
 * Les chiffres viennent de l'API (serverFetch), qui les filtre par rôle et périmètre : la page ne filtre rien.
 * La période (?annee=&mois=) est validée ici une fois pour toutes ; les deux tableaux de bord la reçoivent
 * déjà bornée.
 */
export default async function Accueil({
  searchParams,
}: {
  searchParams: Promise<{ annee?: string | string[]; mois?: string | string[] }>;
}) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;

  const sp = await searchParams;
  // Mois courant À PARIS (fuseau de l'API), pas celui du serveur Next.
  const maintenant = aujourdhuiParis();
  const annee = entierBorne(sp.annee, 2000, 2100) ?? maintenant.getFullYear();
  const mois = entierBorne(sp.mois, 1, 12) ?? maintenant.getMonth() + 1;

  if (estEncadrement(me.role)) return <DashboardDirection me={me} annee={annee} mois={mois} />;
  if (TERRAIN.includes(me.role)) return <DashboardTerrain me={me} annee={annee} mois={mois} />;
  return <AccueilSimple prenom={me.displayName.trim().split(/\s+/)[0] ?? ''} />;
}
