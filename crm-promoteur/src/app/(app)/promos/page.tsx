import { Megaphone, Sparkles, Star } from 'lucide-react';
import { listPromosActives, listPem } from '@/lib/api';

export const metadata = { title: 'Promos / PEM — Selios' };

function dateFr(iso: string | null): string {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default async function PromosPage() {
  const [promos, pem] = await Promise.all([listPromosActives(), listPem()]);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold">Promos / PEM</h1>
        <p className="text-sm text-neutral-500">
          Offres en cours et articles mis en avant à pousser lors de tes visites.
        </p>
      </div>

      {!promos || !pem ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Données indisponibles — réessaie plus tard.
        </p>
      ) : (
        <>
          {/* Promotions en cours */}
          <section className="flex flex-col gap-3">
            <div className="flex items-center gap-2">
              <Megaphone size={18} className="text-brand dark:text-accent" />
              <h2 className="text-lg font-semibold">Promotions en cours</h2>
              <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-semibold text-neutral-500 dark:bg-navy-800 dark:text-neutral-300">
                {promos.length}
              </span>
            </div>
            <div className="rounded-2xl bg-white shadow-card">
              {promos.length === 0 ? (
                <p className="px-5 py-8 text-center text-sm text-neutral-400">
                  Aucune promotion en cours pour le moment.
                </p>
              ) : (
                <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                  {promos.map((p) => (
                    <li key={p.id} className="flex items-center gap-3 px-4 py-3">
                      <Sparkles size={16} className="shrink-0 text-brand dark:text-accent" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">
                          {p.article.libelle}
                          {p.libelle ? <span className="ml-2 text-brand dark:text-accent">{p.libelle}</span> : null}
                        </p>
                        <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-400">
                          <span>{p.article.codeAs400}</span>
                          {p.article.marque ? <span>{p.article.marque.nom}</span> : null}
                          {p.dateFin ? <span>jusqu&apos;au {dateFr(p.dateFin)}</span> : null}
                        </p>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>

          {/* Mises en avant */}
          <section className="flex flex-col gap-3">
            <div className="flex items-center gap-2">
              <Star size={18} className="text-amber-500" />
              <h2 className="text-lg font-semibold">Mises en avant</h2>
              <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-semibold text-neutral-500 dark:bg-navy-800 dark:text-neutral-300">
                {pem.length}
              </span>
            </div>
            <div className="rounded-2xl bg-white shadow-card">
              {pem.length === 0 ? (
                <p className="px-5 py-8 text-center text-sm text-neutral-400">
                  Aucun article mis en avant.
                </p>
              ) : (
                <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                  {pem.map((m) => (
                    <li key={m.id} className="flex items-center gap-3 px-4 py-3">
                      <Star size={16} className="shrink-0 text-amber-500" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium">{m.article.libelle}</p>
                        <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-400">
                          <span>{m.article.codeAs400}</span>
                          {m.article.marque ? <span>{m.article.marque.nom}</span> : null}
                        </p>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
