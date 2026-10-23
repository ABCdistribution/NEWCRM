import { listUsers, listSecteurs, type Paginated, type UserRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { ActiveBadge, ROLE_LABELS } from '@/components/badges';
import { RoleSelect } from '@/components/role-select';
import { ActiveToggle } from '@/components/active-toggle';
import { SecteurSelect } from '@/components/secteur-select';

/** Gestion des comptes : rôle, secteur, activation. Les comptes sont provisionnés depuis l'AD au premier login. */
export async function AdminUtilisateursOnglet({ search, page }: { search: string; page: number }) {
  let result: Paginated<UserRow> | null = null;
  let error: string | null = null;
  try {
    result = await listUsers({ search, page });
  } catch {
    error = "Impossible de charger les utilisateurs. L'API est-elle démarrée ?";
  }
  const secteurs = (await listSecteurs()) ?? [];

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-neutral-500">
          Comptes provisionnés depuis l&apos;Active Directory au premier login. La synchronisation en masse se lance
          depuis l&apos;onglet Synchronisations.
        </p>
        <SearchBar placeholder="Login, nom, email…" conserver={['onglet']} />
      </div>

      {error || !result ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</p>
      ) : (
        <>
          <div className="overflow-x-auto rounded-xl bg-white shadow-card">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500">
                <tr>
                  <th className="px-3 py-2.5 font-medium">Utilisateur</th>
                  <th className="px-3 py-2.5 font-medium">Email</th>
                  <th className="px-3 py-2.5 font-medium">Code repr.</th>
                  <th className="px-3 py-2.5 font-medium">Région / Directeur</th>
                  <th className="px-3 py-2.5 font-medium">Secteur</th>
                  <th className="px-3 py-2.5 font-medium">Rôle</th>
                  <th className="px-3 py-2.5 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {result.data.map((u) => (
                  <tr key={u.id} className="hover:bg-neutral-50">
                    <td className="px-3 py-2.5">
                      <p className="font-medium">{u.displayName}</p>
                      <p className="font-mono text-xs text-neutral-400">{u.username}</p>
                    </td>
                    <td className="px-3 py-2.5 text-neutral-500">{u.email ?? '—'}</td>
                    <td className="px-3 py-2.5 font-mono text-xs">
                      {u.idRepr ?? <span className="text-neutral-400">—</span>}
                    </td>
                    <td className="px-3 py-2.5">
                      {u.region ? (
                        <span className="rounded-md bg-neutral-100 px-1.5 py-0.5 text-xs font-medium">{u.region.nom}</span>
                      ) : (
                        <span className="text-xs text-neutral-400">—</span>
                      )}
                      {u.directeur ? (
                        <p className="mt-0.5 text-xs text-neutral-400">DR : {u.directeur.displayName}</p>
                      ) : null}
                    </td>
                    <td className="px-3 py-2.5">
                      <SecteurSelect
                        userId={u.id}
                        value={u.secteurId}
                        secteurs={secteurs.map((s) => ({ id: s.id, code: s.code, nom: s.nom }))}
                      />
                    </td>
                    <td className="px-3 py-2.5">
                      <RoleSelect userId={u.id} value={u.role} />
                    </td>
                    <td className="px-3 py-2.5">
                      <div className="flex items-center gap-2">
                        <ActiveBadge active={u.isActive} />
                        <ActiveToggle userId={u.id} isActive={u.isActive} />
                      </div>
                    </td>
                  </tr>
                ))}
                {result.data.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-neutral-400">
                      Aucun utilisateur trouvé.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
          <Pagination
            total={result.total}
            page={result.page}
            limit={result.limit}
            params={{ onglet: 'utilisateurs', search }}
          />
          <p className="text-xs text-neutral-400">
            Rôles disponibles : {Object.values(ROLE_LABELS).join(' · ')}. Le code représentant, la région et le
            directeur sont synchronisés depuis l&apos;AD à chaque connexion de l&apos;utilisateur ; le rôle des comptes
            rangés dans une OU de la force de vente l&apos;est aussi, et écrase donc une modification manuelle.
          </p>
        </>
      )}
    </div>
  );
}
