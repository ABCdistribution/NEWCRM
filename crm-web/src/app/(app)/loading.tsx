/** Squelette affiché dès le clic, pendant que le serveur prépare la page (le menu reste en place). */
export default function Loading() {
  return (
    <div className="animate-pulse space-y-6" role="status" aria-label="Chargement de la page">
      <div className="space-y-2">
        <div className="h-7 w-64 rounded-lg bg-neutral-200" />
        <div className="h-4 w-96 max-w-full rounded bg-neutral-100" />
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="h-28 rounded-2xl bg-neutral-100" />
        ))}
      </div>
      <div className="space-y-3 rounded-2xl bg-neutral-100 p-5">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-4 rounded bg-neutral-200" style={{ width: `${95 - i * 7}%` }} />
        ))}
      </div>
      <span className="sr-only">Chargement…</span>
    </div>
  );
}
