import Link from 'next/link';

export function Pagination({
  total,
  page,
  limit,
  params,
}: {
  total: number;
  page: number;
  limit: number;
  /** Paramètres de requête à préserver (ex. search). */
  params?: Record<string, string | undefined>;
}) {
  const pages = Math.max(1, Math.ceil(total / limit));
  const href = (p: number) => {
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(params ?? {})) if (v) sp.set(k, v);
    sp.set('page', String(p));
    return `?${sp}`;
  };

  const btn =
    'rounded-md border border-neutral-300 bg-white px-3 py-1.5 text-sm transition hover:bg-neutral-100 dark:border-navy-700 dark:bg-navy-950 dark:hover:bg-navy-800';
  const disabled = 'pointer-events-none opacity-40';

  return (
    <div className="flex items-center justify-between text-sm text-neutral-500">
      <span>
        {total} résultat{total > 1 ? 's' : ''} · page {page}/{pages}
      </span>
      <div className="flex gap-2">
        <Link href={href(page - 1)} className={`${btn} ${page <= 1 ? disabled : ''}`} aria-disabled={page <= 1}>
          Précédent
        </Link>
        <Link href={href(page + 1)} className={`${btn} ${page >= pages ? disabled : ''}`} aria-disabled={page >= pages}>
          Suivant
        </Link>
      </div>
    </div>
  );
}
