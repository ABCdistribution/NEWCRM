import { requireRole, TOUS_ROLES } from '@/lib/roles';
import { Pagination } from '@/components/pagination';
import { ClientsFiltres } from '@/components/clients-filtres';
import { ClientsListe } from '@/components/clients-liste';
import { aUnPerimetre, chargerClients, lireFiltresClients, LIMITE_CLIENTS } from '@/lib/clients-liste';

export const metadata = { title: 'Les clients' };

type SearchParams = { search?: string; page?: string; niveau?: string; statut?: string; tous?: string };

const NB = new Intl.NumberFormat('fr-FR');

const ALERTE =
  'rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300';

/**
 * Liste des clients, la même pour tous les rôles : nombre de clients (actifs / inactifs), recherche, niveau, état et
 * « Mes clients » (promoteur, chef de secteur, directeur régional : uniquement les clients de leur périmètre, activé par
 * défaut). Les autres rôles (siège, direction, admin, ADV, marketing) voient tout le référentiel.
 * Le périmètre (utilisateur / secteur / région) est filtré par l'API ; la page ne filtre rien.
 */
export default async function ClientsPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;

  const f = lireFiltresClients(await searchParams, me.role);
  const avecMes = aUnPerimetre(me.role);
  const r = await chargerClients(f);

  return (
    <div className="flex flex-col gap-4">
      <h1 className="sr-only">Les clients</h1>

      {r ? (
        <p className="flex flex-wrap items-baseline gap-x-4 gap-y-1" aria-live="polite">
          <span className="text-3xl font-bold tabular-nums">{NB.format(r.compteurs.total)}</span>
          <span className="text-neutral-500">{f.mes ? 'clients dans mon secteur' : 'clients référencés'}</span>
          <span className="inline-flex items-center gap-1.5 text-sm font-medium text-emerald-800">
            <span className="h-2 w-2 rounded-full bg-positif" aria-hidden />
            {NB.format(r.compteurs.actifs)} actifs
          </span>
          <span className="inline-flex items-center gap-1.5 text-sm font-medium text-red-700">
            <span className="h-2 w-2 rounded-full bg-red-500" aria-hidden />
            {NB.format(r.compteurs.inactifs)} inactifs
          </span>
        </p>
      ) : null}

      <ClientsFiltres search={f.search} niveau={f.niveau} statut={f.statut} mes={f.mes} avecMes={avecMes} />

      {r === null ? (
        <p className={ALERTE} role="alert">
          Impossible de charger les clients. L&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          <ClientsListe clients={r.liste.data} />
          <Pagination
            total={r.liste.total}
            page={r.liste.page}
            limit={LIMITE_CLIENTS}
            unite="client"
            params={{
              search: f.search,
              niveau: f.niveau,
              ...(f.statut !== 'actifs' ? { statut: f.statut } : {}),
              ...(avecMes && !f.mes ? { tous: '1' } : {}),
            }}
          />
        </>
      )}
    </div>
  );
}
