import { getMe, listMagasinsSuivi, listMagasinsGeo, listProspects, type ProspectRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { AccesRefuse } from '@/components/acces-refuse';
import { MagasinsSecteurBoard } from '@/components/magasins-secteur-board';

export const metadata = { title: 'Magasins — Helios' };

const ALLOWED = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADMIN'];

export default async function MagasinsSecteurPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  const [magasins, points] = await Promise.all([listMagasinsSuivi({ search, page }), listMagasinsGeo()]);

  // Prospects « pas encore travaillés » : non convertis, non perdus (pour la carte).
  const prospects: ProspectRow[] = [];
  try {
    for (let p = 1; p <= 5; p++) {
      const res = await listProspects({ page: p });
      prospects.push(...res.data.filter((x) => !x.clientId && x.statut !== 'PERDU'));
      if (p * res.limit >= res.total) break;
    }
  } catch {
    // carte sans prospects si l'API prospection est indisponible
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Magasins</h1>
        <SearchBar placeholder="Enseigne, raison sociale, code…" />
      </div>

      {magasins === null ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Magasins indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          <MagasinsSecteurBoard magasins={magasins.data} points={points ?? []} prospects={prospects} />
          <Pagination total={magasins.total} page={magasins.page} limit={magasins.limit} params={{ search }} unite="magasin" />
        </>
      )}
    </div>
  );
}
