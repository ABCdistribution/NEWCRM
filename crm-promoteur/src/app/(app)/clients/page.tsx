import { listClientsEnriched, type ClientsEnrichedResult } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { MagasinsTable } from '@/components/magasins-table';
import { MesMagasinsToggle } from '@/components/mes-magasins-toggle';
import { StatutMagasinsFiltre, type StatutMagasins } from '@/components/statut-magasins-filtre';

export const metadata = { title: 'Mes magasins — ABC Sales' };

export default async function ClientsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string; tous?: string; statut?: string }>;
}) {
  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const tous = sp.tous === '1' ? '1' : undefined;
  const statut: StatutMagasins = sp.statut === 'actifs' || sp.statut === 'inactifs' ? sp.statut : undefined;

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
    error = "Impossible de charger les magasins. L'API est-elle démarrée ?";
  }

  const mine = result?.scope?.type === 'mine';
  // Le filtre n'a de sens que pour un commercial : soit il est scopé (mine),
  // soit il vient de décocher (tous=1).
  const filtrable = mine || tous === '1';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{mine ? 'Mes magasins' : 'Magasins'}</h1>
          <p className="text-sm text-neutral-500">
            {mine
              ? `Mon portefeuille (code représentant ${result!.scope.idRepr})`
              : 'Référentiel complet des magasins.'}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {filtrable ? <MesMagasinsToggle /> : null}
          <SearchBar placeholder="Enseigne, raison sociale, code…" conserver={['tous', 'statut']} />
        </div>
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          <StatutMagasinsFiltre statut={statut} params={{ search, tous }} />
          <MagasinsTable rows={result!.data} />
          <Pagination total={result!.total} page={result!.page} limit={result!.limit} params={{ search, ...(tous ? { tous } : {}), ...(statut ? { statut } : {}) }} />
        </>
      )}
    </div>
  );
}
