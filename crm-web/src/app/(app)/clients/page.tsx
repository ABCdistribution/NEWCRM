import Link from 'next/link';
import { listClientsEnriched, listMagasinsSuivi, type ClientsEnrichedResult } from '@/lib/api';
import { estEncadrement, requireRole, TOUS_ROLES } from '@/lib/roles';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { MagasinsTable } from '@/components/magasins-table';
import { MesMagasinsToggle } from '@/components/mes-magasins-toggle';
import { StatutMagasinsFiltre, type StatutMagasins } from '@/components/statut-magasins-filtre';
import { MagasinsSecteurBoard } from '@/components/magasins-secteur-board';

export const metadata = { title: 'Les clients' };

type SearchParams = { search?: string; page?: string; tous?: string; statut?: string; vue?: string };

const ALERTE =
  'rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300';

/**
 * Liste des clients, selon le rôle :
 *  - terrain (COMMERCIAL, ADV) et autres rôles : vue « portefeuille » (tableau, « mes clients uniquement ») ;
 *  - encadrement : vue « suivi » du secteur (tableau de suivi, sans carte : la page client est à refaire) par défaut, et vue
 *    « portefeuille » via `?vue=portefeuille` (l'encadrement garde l'accès aux écrans terrain).
 * Le périmètre (utilisateur / secteur / région) est filtré par l'API.
 */
export default async function ClientsPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  const { me } = acces;

  const sp = await searchParams;
  const encadrement = estEncadrement(me.role);
  const vue: 'suivi' | 'portefeuille' = encadrement && sp.vue !== 'portefeuille' ? 'suivi' : 'portefeuille';

  return (
    <div className="flex flex-col gap-4">
      {encadrement ? <OngletsVue vue={vue} /> : null}
      {vue === 'suivi' ? <VueSuivi sp={sp} /> : <VuePortefeuille sp={sp} encadrement={encadrement} />}
    </div>
  );
}

/** Bascule suivi du secteur / portefeuille (encadrement). */
function OngletsVue({ vue }: { vue: 'suivi' | 'portefeuille' }) {
  const onglet = (actif: boolean) =>
    `rounded-lg px-3 py-1.5 text-sm font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent ${
      actif
        ? 'bg-brand text-white dark:bg-accent dark:text-brand'
        : 'text-neutral-500 hover:bg-neutral-100 dark:hover:bg-navy-800'
    }`;
  return (
    <nav aria-label="Vue des clients" className="flex flex-wrap gap-1.5">
      <Link href="/clients" className={onglet(vue === 'suivi')} aria-current={vue === 'suivi' ? 'page' : undefined}>
        Suivi du secteur
      </Link>
      <Link
        href="/clients?vue=portefeuille"
        className={onglet(vue === 'portefeuille')}
        aria-current={vue === 'portefeuille' ? 'page' : undefined}
      >
        Portefeuille
      </Link>
    </nav>
  );
}

/** Vue de suivi du secteur (encadrement) : tableau de suivi et détail du magasin. */
async function VueSuivi({ sp }: { sp: SearchParams }) {
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  const magasins = await listMagasinsSuivi({ search, page });

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Suivi des clients</h1>
        <SearchBar placeholder="Enseigne, raison sociale, code…" />
      </div>

      {magasins === null ? (
        <p className={ALERTE} role="alert">
          Clients indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          <MagasinsSecteurBoard magasins={magasins.data} />
          <Pagination total={magasins.total} page={magasins.page} limit={magasins.limit} params={{ search }} unite="client" />
        </>
      )}
    </>
  );
}

/** Vue portefeuille : tableau des clients avec filtres « mes clients » et actif / inactif. */
async function VuePortefeuille({ sp, encadrement }: { sp: SearchParams; encadrement: boolean }) {
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const tous = sp.tous === '1' ? '1' : undefined;
  const statut: StatutMagasins = sp.statut === 'actifs' || sp.statut === 'inactifs' ? sp.statut : undefined;
  // Pour l'encadrement, la page garde `vue=portefeuille` dans les liens de pagination / filtres.
  const vue = encadrement ? 'portefeuille' : undefined;

  let result: ClientsEnrichedResult | null = null;
  let error: string | null = null;
  try {
    result = await listClientsEnriched({
      search,
      page,
      tous,
      actif: statut ? (statut === 'actifs' ? 'true' : 'false') : undefined,
    });
  } catch {
    error = "Impossible de charger les clients. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';
  // Le filtre n'a de sens que pour un commercial : soit il est scopé (mine),
  // soit il vient de décocher (tous=1).
  const filtrable = mine || tous === '1';

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{mine ? 'Mes clients' : 'Clients'}</h1>
          <p className="text-sm text-neutral-500">
            {mine
              ? `Mon portefeuille (code représentant ${result!.scope.idRepr})`
              : 'Référentiel complet des clients.'}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {filtrable ? <MesMagasinsToggle /> : null}
          <SearchBar placeholder="Enseigne, raison sociale, code…" conserver={['tous', 'statut', 'vue']} />
        </div>
      </div>

      {error ? (
        <p className={ALERTE} role="alert">
          {error}
        </p>
      ) : (
        <>
          <StatutMagasinsFiltre statut={statut} params={{ search, tous, vue }} />
          <MagasinsTable rows={result!.data} />
          <Pagination
            total={result!.total}
            page={result!.page}
            limit={result!.limit}
            params={{ search, ...(tous ? { tous } : {}), ...(statut ? { statut } : {}), ...(vue ? { vue } : {}) }}
          />
        </>
      )}
    </>
  );
}
