import Link from 'next/link';
import { getProspectPipeline, type ProspectRow, type ProspectStatut } from '@/lib/api';
import { ENCADREMENT, requireRole } from '@/lib/roles';
import { peutEcrireProspects } from '@/lib/prospect-roles';
import { listSecteursProposables } from '@/lib/prospect-secteurs';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { KpiTile } from '@/components/kpi-tile';
import { StatutBadge, SOURCE_LABELS } from '@/components/prospect-badges';
import { ProspectEtapeSelect } from '@/components/prospect-etape-select';
import { ProspectCreate } from '@/components/prospect-create';

export const metadata = { title: 'Prospection — Direction commerciale' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const NB = new Intl.NumberFormat('fr-FR');
const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
const fmt = (n: number | null) => (n == null ? '—' : NB.format(n));

/** Étapes en cours : « Gagné » et « Perdu » ne figurent pas dans le tableau. */
const ETAPES_ACTIVES: ProspectStatut[] = ['NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION'];
/** Un prospect sans activité depuis ce nombre de jours est « à relancer ». */
const DORMANT_JOURS = 14;
const PAR_PAGE = 20;

type LigneProspect = ProspectRow & { inactifDepuis: number };

export default async function ProspectsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string }>;
}) {
  // Encadrement uniquement (même règle que le layout et la table des routes) ; le périmètre est filtré par l'API.
  const acces = await requireRole(ENCADREMENT);
  if (acces.refuse) return acces.refuse;

  const sp = await searchParams;
  const search = (sp.search ?? '').trim();
  const demandee = Math.max(1, Math.floor(Number(sp.page ?? '1')) || 1);

  // Écriture (création, changement d'étape) : ADMIN, DR et CS seulement, comme l'API ; DIRECTION consulte en lecture seule.
  const peutEcrire = peutEcrireProspects(acces.me.role);
  // Secteurs proposables pour un nouveau prospect : GET /prospects/secteurs (périmètre du rôle), pas /secteurs
  // (réservé ADMIN, 403 pour CS et DR). Inutile, et refusé par l'API, pour un rôle qui ne crée pas.
  const [pipeline, secteursProposables] = await Promise.all([
    getProspectPipeline(),
    peutEcrire ? listSecteursProposables() : Promise.resolve([]),
  ]);

  // --- Indicateurs et tableau, dérivés du pipeline complet (une seule requête, périmètre filtré par l'API) ------
  const colonnes = pipeline ?? [];
  const actifs: ProspectRow[] = colonnes.filter((c) => ETAPES_ACTIVES.includes(c.statut)).flatMap((c) => c.prospects);

  const maintenant = Date.now();
  const joursDepuis = (iso: string | null) =>
    iso ? Math.floor((maintenant - new Date(iso).getTime()) / 86_400_000) : null;
  const lignes: LigneProspect[] = actifs.map((p) => ({
    ...p,
    inactifDepuis: joursDepuis(p.lastActivityAt ?? p.createdAt) ?? 0,
  }));
  // Les trois tuiles ne se recoupent pas : un prospect inactif depuis 14 jours est « à relancer », quelle que soit son étape.
  const dormant = (p: LigneProspect) => p.inactifDepuis >= DORMANT_JOURS;
  const nbARelancer = lignes.filter(dormant).length;
  const nbAContacter = lignes.filter((p) => !dormant(p) && p.statut === 'NOUVEAU').length;
  const nbRdvAPrendre = lignes.filter((p) => !dormant(p) && (p.statut === 'CONTACTE' || p.statut === 'PROPOSITION')).length;
  const nbOuTiret = (n: number) => (n > 0 ? fmt(n) : '—');

  // Recherche (enseigne, raison sociale, ville), puis les plus anciennement relancés en premier.
  const terme = search.toLowerCase();
  const filtrees = lignes
    .filter(
      (p) =>
        !terme ||
        [p.enseigne, p.raisonSociale, p.ville].some((v) => v?.toLowerCase().includes(terme)),
    )
    .sort((a, b) => b.inactifDepuis - a.inactifDepuis);
  const pages = Math.max(1, Math.ceil(filtrees.length / PAR_PAGE));
  const page = Math.min(demandee, pages);
  const visibles = filtrees.slice((page - 1) * PAR_PAGE, page * PAR_PAGE);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Prospection</h1>
        </div>
        <div className="flex items-center gap-2">
          <SearchBar placeholder="Enseigne, raison sociale…" />
          {peutEcrire ? (
            <ProspectCreate secteurs={secteursProposables ?? []} secteursIndisponibles={secteursProposables === null} />
          ) : null}
        </div>
      </div>

      {/* KPI business */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-3">
        <KpiTile label="À contacter" value={nbOuTiret(nbAContacter)} sub="Premier contact" />
        <KpiTile label="À relancer" value={nbOuTiret(nbARelancer)} sub="Suivi à effectuer" />
        <KpiTile label="RDV à prendre" value={nbOuTiret(nbRdvAPrendre)} sub="À organiser" />
      </section>

      {pipeline === null ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Impossible de charger les prospects. L&apos;API est-elle démarrée ?
        </p>
      ) : (
        <ListeView
          lignes={visibles}
          offset={(page - 1) * PAR_PAGE}
          total={filtrees.length}
          page={page}
          search={search}
          peutEcrire={peutEcrire}
        />
      )}
    </div>
  );
}

function ListeView({
  lignes,
  offset,
  total,
  page,
  search,
  peutEcrire,
}: {
  lignes: LigneProspect[];
  offset: number;
  total: number;
  page: number;
  search: string;
  peutEcrire: boolean;
}) {
  return (
    <>
      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">#</th>
              <th className="px-4 py-2.5 font-medium">Prospect</th>
              <th className="px-4 py-2.5 font-medium">Société</th>
              <th className="px-4 py-2.5 font-medium">Source</th>
              <th className="px-4 py-2.5 font-medium">Responsable</th>
              <th className="px-4 py-2.5 text-right font-medium">Potentiel/an</th>
              <th className="px-4 py-2.5 font-medium">Étape</th>
              <th className="px-4 py-2.5 text-right font-medium">Inactif depuis</th>
              <th className="px-4 py-2.5 font-medium">Créé le</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {lignes.map((p, i) => (
              <tr key={p.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-3 text-neutral-400 tabular-nums">{offset + i + 1}</td>
                <td className="px-4 py-3">
                  <Link href={`/prospects/${p.id}`} className="absolute inset-0" aria-label={`Fiche ${p.enseigne}`} />
                  <p className="font-medium text-brand dark:text-accent">{p.enseigne}</p>
                  {p.ville ? <p className="text-xs text-neutral-400">{p.ville}</p> : null}
                </td>
                <td className="px-4 py-3 text-neutral-500">{p.raisonSociale}</td>
                <td className="px-4 py-3 text-neutral-500">{p.source ? SOURCE_LABELS[p.source] ?? p.source : '—'}</td>
                <td className="px-4 py-3">
                  {p.assignedTo ? (
                    p.assignedTo.displayName
                  ) : (
                    <span className="text-xs text-neutral-400">Non assigné</span>
                  )}
                </td>
                <td className="px-4 py-3 text-right font-medium tabular-nums">
                  {p.potentielCaAnnuel != null ? EUR.format(p.potentielCaAnnuel) : '—'}
                </td>
                <td className="px-4 py-3">
                  {peutEcrire ? (
                    <ProspectEtapeSelect id={p.id} statut={p.statut} enseigne={p.enseigne} />
                  ) : (
                    <StatutBadge value={p.statut} />
                  )}
                </td>
                <td
                  className={`px-4 py-3 text-right tabular-nums ${
                    p.inactifDepuis >= DORMANT_JOURS ? 'font-semibold text-red-700' : 'text-neutral-500'
                  }`}
                >
                  {p.inactifDepuis} j
                </td>
                <td className="px-4 py-3 text-neutral-500">
                  {p.createdAt ? DT.format(new Date(p.createdAt)) : '—'}
                </td>
              </tr>
            ))}
            {lignes.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-neutral-400">
                  Aucun prospect{search ? ' pour cette recherche' : ' en cours'}.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
      <Pagination total={total} page={page} limit={PAR_PAGE} params={{ search }} unite="prospect" />
    </>
  );
}
