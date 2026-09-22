import { redirect } from 'next/navigation';
import Link from 'next/link';
import { getMe, listUsers, type Paginated, type Role, type UserRow } from '@/lib/api';
import { SearchBar } from '@/components/search-bar';
import { Pagination } from '@/components/pagination';
import { RoleSelect, ActifToggle, SyncAdButton } from '@/components/user-admin-controls';

export const metadata = { title: 'Utilisateurs — Selios' };

/** Rôles filtrables, dans l'ordre hiérarchique d'affichage. */
const ROLES_FILTRE: { value: Role; label: string }[] = [
  { value: 'ADMIN', label: 'Admin' },
  { value: 'DIRECTION', label: 'Direction' },
  { value: 'DIRECTEUR_REGIONAL', label: 'Dir. régional' },
  { value: 'CHEF_SECTEUR', label: 'Chef de secteur' },
  { value: 'COMMERCIAL', label: 'Promoteur' },
  { value: 'ADV', label: 'ADV' },
  { value: 'MARKETING', label: 'Marketing' },
];

const chip = 'rounded-full border px-3 py-1 text-xs font-medium transition';
const chipOff =
  'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800';
const chipOn = 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand';

export default async function UtilisateursPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; page?: string; role?: string }>;
}) {
  const me = await getMe();
  if (!me) redirect('/login');
  if (me.role !== 'ADMIN') {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700 dark:border-red-900/50 dark:bg-red-950/30 dark:text-red-400">
        <h1 className="text-lg font-semibold">Accès refusé</h1>
        <p className="mt-1 text-sm">Cette page est réservée aux administrateurs.</p>
      </div>
    );
  }

  const sp = await searchParams;
  const search = sp.search ?? '';
  const page = Number(sp.page ?? '1') || 1;
  const role = ROLES_FILTRE.some((r) => r.value === sp.role) ? (sp.role as Role) : undefined;

  let result: Paginated<UserRow> | null = null;
  let error: string | null = null;
  try {
    result = await listUsers({ search, page, role });
  } catch {
    error = "Impossible de charger les utilisateurs. L'API est-elle démarrée ?";
  }

  /** URL de la page avec un autre filtre de rôle (recherche conservée, pagination remise à 1). */
  const avecRole = (r?: Role) => {
    const q = new URLSearchParams();
    if (search) q.set('search', search);
    if (r) q.set('role', r);
    const s = q.toString();
    return s ? `/utilisateurs?${s}` : '/utilisateurs';
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Utilisateurs</h1>
          <p className="text-sm text-neutral-500">
            Comptes provisionnés depuis l&apos;Active Directory — rôle et activation gérés ici.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <SearchBar placeholder="Login, nom, email…" />
          <SyncAdButton />
        </div>
      </div>

      {/* Filtre par rôle (côté API : GET /users?role=). */}
      <div className="flex flex-wrap items-center gap-1.5 rounded-2xl bg-white p-3 shadow-card">
        <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Rôle</span>
        <Link href={avecRole()} className={`${chip} ${role === undefined ? chipOn : chipOff}`}>
          Tous
        </Link>
        {ROLES_FILTRE.map((r) => (
          <Link key={r.value} href={avecRole(r.value)} className={`${chip} ${role === r.value ? chipOn : chipOff}`}>
            {r.label}
          </Link>
        ))}
      </div>

      {error ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          {error}
        </p>
      ) : (
        <>
          {/* < md : cartes utilisateurs. */}
          <ul className="flex flex-col gap-2.5 md:hidden">
            {result!.data.map((u) => (
              <li key={u.id} className="rounded-2xl bg-white p-4 shadow-card">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">{u.displayName}</p>
                    <p className="truncate text-xs text-neutral-400">
                      {u.username}
                      {u.idRepr ? ` · code ${u.idRepr}` : ''}
                    </p>
                  </div>
                  <ActifToggle userId={u.id} actif={u.isActive} disabled={u.id === me.id} />
                </div>
                <div className="mt-2.5">
                  <RoleSelect userId={u.id} role={u.role} disabled={u.id === me.id} />
                </div>
              </li>
            ))}
            {result!.data.length === 0 ? (
              <li className="rounded-2xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
                Aucun utilisateur trouvé.
              </li>
            ) : null}
          </ul>

          {/* ≥ md : tableau. */}
          <div className="hidden overflow-x-auto rounded-xl bg-white shadow-card md:block">
            <table className="w-full min-w-[720px] text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Utilisateur</th>
                  <th className="px-4 py-2.5 font-medium">Email</th>
                  <th className="px-4 py-2.5 font-medium">Code repr</th>
                  <th className="px-4 py-2.5 font-medium">Rôle</th>
                  <th className="px-4 py-2.5 font-medium">Statut</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {result!.data.map((u) => (
                  <tr key={u.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-4 py-2.5">
                      <div className="font-medium">{u.displayName}</div>
                      <div className="text-xs text-neutral-400">{u.username}</div>
                    </td>
                    <td className="px-4 py-2.5 text-neutral-500">{u.email ?? '—'}</td>
                    <td className="px-4 py-2.5 font-mono text-xs">{u.idRepr ?? '—'}</td>
                    <td className="px-4 py-2.5">
                      <RoleSelect userId={u.id} role={u.role} disabled={u.id === me.id} />
                    </td>
                    <td className="px-4 py-2.5">
                      <ActifToggle userId={u.id} actif={u.isActive} disabled={u.id === me.id} />
                    </td>
                  </tr>
                ))}
                {result!.data.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-neutral-400">
                      Aucun utilisateur trouvé.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
          <Pagination
            total={result!.total}
            page={result!.page}
            limit={result!.limit}
            params={{ search, ...(role ? { role } : {}) }}
          />
        </>
      )}
    </div>
  );
}
