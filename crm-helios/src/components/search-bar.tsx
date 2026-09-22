'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';

export function SearchBar({ placeholder = 'Rechercher…' }: { placeholder?: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const value = String(new FormData(e.currentTarget).get('search') ?? '').trim();
    const params = new URLSearchParams();
    if (value) params.set('search', value);
    router.push(`${pathname}${params.toString() ? `?${params}` : ''}`);
  }

  return (
    <form onSubmit={onSubmit} className="flex gap-2">
      <input
        name="search"
        type="search"
        defaultValue={searchParams.get('search') ?? ''}
        placeholder={placeholder}
        className="w-full max-w-xs rounded-lg border border-neutral-300 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand focus:ring-2 focus:ring-brand/30 dark:border-navy-700 dark:bg-navy-950"
      />
      <button
        type="submit"
        className="rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        Rechercher
      </button>
    </form>
  );
}
