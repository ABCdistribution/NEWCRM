import { CheckCircle2, TriangleAlert } from 'lucide-react';
import type { AdminOrganisation } from '@/lib/api';

const INCOHERENCES: { cle: keyof AdminOrganisation['incoherences']; libelle: string }[] = [
  { cle: 'promoteursSansSecteur', libelle: 'Promoteurs sans secteur' },
  { cle: 'promoteursSansDirecteur', libelle: 'Promoteurs sans directeur' },
  { cle: 'promoteursDirecteurInactif', libelle: 'Promoteurs rattachés à un directeur inactif' },
  { cle: 'secteursSansChef', libelle: 'Secteurs sans chef de secteur' },
  { cle: 'chefsInactifs', libelle: 'Secteurs dont le chef est inactif' },
  { cle: 'regionsSansDirecteur', libelle: 'Régions sans directeur actif' },
  { cle: 'secteursSansRegion', libelle: 'Secteurs sans région' },
];

function Nom({ nom, actif = true }: { nom: string; actif?: boolean }) {
  return <span className={actif ? '' : 'text-neutral-400 line-through'}>{nom}</span>;
}

/** Contrôles de cohérence + arbre Région → Directeur → Chef de secteur → Promoteur. */
export function AdminOrganisationOnglet({ data }: { data: AdminOrganisation }) {
  const aCorriger = INCOHERENCES.filter((i) => data.incoherences[i.cle].total > 0);

  return (
    <div className="flex flex-col gap-5">
      <section className="rounded-2xl bg-white shadow-card">
        <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 text-sm font-semibold">
          {aCorriger.length === 0 ? (
            <CheckCircle2 size={16} className="text-emerald-600" aria-hidden />
          ) : (
            <TriangleAlert size={16} className="text-amber-600" aria-hidden />
          )}
          Contrôles de cohérence
        </h2>
        {aCorriger.length === 0 ? (
          <p className="px-5 py-4 text-sm text-neutral-500">Aucune incohérence détectée dans l&apos;organisation.</p>
        ) : (
          <ul className="divide-y divide-neutral-100">
            {aCorriger.map((i) => {
              const { total, items } = data.incoherences[i.cle];
              return (
                <li key={i.cle}>
                  <details className="group px-5 py-3">
                    <summary className="flex cursor-pointer list-none items-center justify-between gap-3 text-sm">
                      <span>{i.libelle}</span>
                      <span className="rounded-full bg-amber-50 px-2.5 py-0.5 text-xs font-semibold tabular-nums text-amber-700">
                        {total}
                      </span>
                    </summary>
                    <ul className="mt-2 columns-1 gap-6 text-sm text-neutral-600 sm:columns-2 xl:columns-3">
                      {items.map((p) => (
                        <li key={p.id} className="break-inside-avoid py-0.5">
                          {p.displayName}
                        </li>
                      ))}
                    </ul>
                    {total > items.length ? (
                      <p className="mt-1 text-xs text-neutral-400">… et {total - items.length} autre(s).</p>
                    ) : null}
                  </details>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {data.regions.length === 0 ? (
        <p className="rounded-2xl border border-dashed border-neutral-300 p-8 text-center text-sm text-neutral-400">
          Aucune région configurée.
        </p>
      ) : (
        data.regions.map((r) => (
          <section key={r.id} className="rounded-2xl bg-white shadow-card">
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b border-neutral-100 px-5 py-3">
              <h2 className="text-sm font-semibold">{r.nom}</h2>
              <span className="text-xs text-neutral-400">
                Directeur régional :{' '}
                {r.directeurs.length === 0 ? (
                  <span className="text-amber-600">aucun</span>
                ) : (
                  r.directeurs.map((d, i) => (
                    <span key={d.id}>
                      {i > 0 ? ', ' : ''}
                      <Nom nom={d.displayName} actif={d.isActive} />
                    </span>
                  ))
                )}
              </span>
            </div>
            <div className="grid grid-cols-1 gap-3 p-4 lg:grid-cols-2 xl:grid-cols-3">
              {r.secteurs.length === 0 ? (
                <p className="text-sm text-neutral-400">Aucun secteur.</p>
              ) : (
                r.secteurs.map((s) => (
                  <div key={s.id} className="rounded-xl border border-neutral-100 p-3">
                    <p className="text-sm font-semibold">
                      <span className="mr-1.5 rounded-md bg-neutral-100 px-1.5 py-0.5 font-mono text-xs">{s.code}</span>
                      {s.nom}
                    </p>
                    <p className="mt-1 text-xs text-neutral-500">
                      Chef de secteur :{' '}
                      {s.manager ? (
                        <Nom nom={s.manager.displayName} actif={s.manager.isActive} />
                      ) : (
                        <span className="text-amber-600">non défini</span>
                      )}
                    </p>
                    <p className="mt-2 text-xs font-medium text-neutral-400">
                      {s.promoteurs.length} promoteur{s.promoteurs.length > 1 ? 's' : ''}
                    </p>
                    {s.promoteurs.length > 0 ? (
                      <ul className="mt-1 text-sm text-neutral-700">
                        {s.promoteurs.map((p) => (
                          <li key={p.id} className="flex items-center justify-between gap-2 py-0.5">
                            <Nom nom={p.displayName} actif={p.isActive} />
                            <span className="font-mono text-xs text-neutral-400">{p.idRepr ?? '—'}</span>
                          </li>
                        ))}
                      </ul>
                    ) : null}
                  </div>
                ))
              )}
            </div>
          </section>
        ))
      )}

      {data.secteursSansRegion.length > 0 ? (
        <section className="rounded-2xl border border-amber-200 bg-amber-50/50 p-4 text-sm text-amber-800">
          Secteurs sans région : {data.secteursSansRegion.map((s) => `${s.code} — ${s.nom}`).join(', ')}
        </section>
      ) : null}
    </div>
  );
}
