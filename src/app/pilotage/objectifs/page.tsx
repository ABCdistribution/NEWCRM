import Link from 'next/link';
import { ChevronLeft, ChevronRight, ShieldAlert, Target } from 'lucide-react';
import { getMe, getObjectifsGrille } from '@/lib/api';
import { ObjectifInput } from '@/components/objectif-input';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ClassBadge } from '@/components/class-badge';

export const metadata = { title: 'Objectifs — Helios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

export default async function ObjectifsPage({
  searchParams,
}: {
  searchParams: Promise<{ annee?: string; search?: string; page?: string }>;
}) {
  const me = await getMe();
  // Saisie réservée à la direction (Grégory Sylvestre) et aux admins.
  if (!me || !['ADMIN', 'DIRECTION'].includes(me.role)) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
        <h1 className="flex items-center gap-2 text-lg font-semibold">
          <ShieldAlert size={20} />
          Accès refusé
        </h1>
        <p className="mt-1 text-sm">La saisie des objectifs est réservée à la direction.</p>
      </div>
    );
  }

  const sp = await searchParams;
  const annee = Number(sp.annee) || new Date().getFullYear();
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;

  const grille = await getObjectifsGrille(annee, { search: search || undefined, page });

  const anneeQs = (a: number) =>
    `/pilotage/objectifs?annee=${a}${search ? `&search=${encodeURIComponent(search)}` : ''}`;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Objectifs annuels par magasin</h1>
          <p className="text-sm text-neutral-500">
            La cible se saisit magasin par magasin — l&apos;objectif d&apos;un promoteur est calculé
            (somme de son portefeuille, ÷ 12 pour le mensuel des jauges kratos).
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <SearchBar placeholder="Enseigne, ville, code AS400…" />
          {/* Sélecteur d'année */}
          <div className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
            <Link
              href={anneeQs(annee - 1)}
              className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
              aria-label="Année précédente"
            >
              <ChevronLeft size={16} />
            </Link>
            <span className="min-w-16 text-center text-sm font-semibold text-brand dark:text-accent">{annee}</span>
            <Link
              href={anneeQs(annee + 1)}
              className="rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
              aria-label="Année suivante"
            >
              <ChevronRight size={16} />
            </Link>
          </div>
        </div>
      </div>

      {!grille ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Grille indisponible — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          {/* Totaux de l'année sur le périmètre filtré */}
          <div className="flex flex-wrap gap-4 text-sm text-neutral-500">
            <span>
              <span className="font-semibold text-neutral-700">{grille.totaux.magasins}</span> magasin{grille.totaux.magasins > 1 ? 's' : ''}
              {' · '}
              <span className="font-semibold text-neutral-700">{grille.totaux.avecObjectif}</span> avec objectif
            </span>
            <span>
              Objectif {annee} cumulé : <span className="font-semibold text-brand">{EUR.format(grille.totaux.cibleCa)}</span>
            </span>
          </div>

          {grille.lignes.length === 0 ? (
            <div className="rounded-2xl bg-white p-10 text-center shadow-card">
              <Target size={32} className="mx-auto text-[#A78BDA]" />
              <p className="mt-3 font-medium">Aucun magasin trouvé.</p>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto rounded-xl bg-white shadow-card">
                <table className="w-full text-sm">
                  <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
                    <tr>
                      <th className="px-4 py-2.5 font-medium">Magasin</th>
                      <th className="px-4 py-2.5 font-medium">Ville</th>
                      <th className="px-4 py-2.5 text-right font-medium">CA réalisé {annee}</th>
                      <th className="px-4 py-2.5 text-right font-medium">Objectif {annee} (€)</th>
                      <th className="px-4 py-2.5 text-right font-medium">Atteinte</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                    {grille.lignes.map((l) => {
                      const taux =
                        l.cibleCa && l.cibleCa > 0 ? Math.round((l.caRealise / l.cibleCa) * 100) : null;
                      return (
                        <tr key={l.clientId} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                          <td className="px-4 py-2.5">
                            <span className="flex items-center gap-2">
                              <Link
                                href={`/pilotage/clients/${l.clientId}`}
                                className="font-medium text-brand hover:underline dark:text-accent"
                              >
                                {l.nom}
                              </Link>
                              <ClassBadge value={l.niveauClass} size="xs" />
                            </span>
                            <span className="font-mono text-[11px] text-neutral-400">{l.codeAs400}</span>
                          </td>
                          <td className="px-4 py-2.5 text-neutral-500">{l.ville ?? '—'}</td>
                          <td className="px-4 py-2.5 text-right dark:text-accent">{EUR.format(l.caRealise)}</td>
                          <td className="px-4 py-2.5 text-right">
                            <ObjectifInput clientId={l.clientId} annee={annee} value={l.cibleCa} />
                          </td>
                          <td className="px-4 py-2.5 text-right">
                            {taux === null ? (
                              <span className="text-neutral-400">—</span>
                            ) : (
                              <span
                                className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                                  taux >= 100
                                    ? 'bg-emerald-500/10 text-emerald-500'
                                    : taux >= 70
                                      ? 'bg-accent/10 text-accent'
                                      : 'bg-red-500/10 text-red-400'
                                }`}
                              >
                                {taux}%
                              </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <Pagination
                total={grille.total}
                page={grille.page}
                limit={grille.limit}
                params={{ annee: String(annee), search: search || undefined }}
              />
            </>
          )}
        </>
      )}
    </div>
  );
}
