import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, CheckCircle2, ChevronLeft, ChevronRight, Route, Sprout, Store } from 'lucide-react';
import { listPlanningMembre } from '@/lib/api';
import { ClassBadge } from '@/components/class-badge';

export const metadata = { title: "Planning d'activité — Helios" };

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const DAY_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

function mondayOf(d: Date): Date {
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return monday;
}
function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export default async function PlanningMembrePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ semaine?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;

  const monday = mondayOf(sp.semaine ? new Date(sp.semaine) : new Date());
  const nextMonday = new Date(monday);
  nextMonday.setDate(nextMonday.getDate() + 7);
  const prevMonday = new Date(monday);
  prevMonday.setDate(prevMonday.getDate() - 7);

  const result = await listPlanningMembre(id, iso(monday), iso(nextMonday));
  if (!result) notFound();
  const { user, etapes } = result;

  const days = JOURS.map((nom, idx) => {
    const d = new Date(monday);
    d.setDate(d.getDate() + idx);
    const date = iso(d);
    return { date, nom, label: DAY_FMT.format(d), etapes: etapes.filter((e) => e.datePassage.slice(0, 10) === date) };
  });
  const faites = etapes.filter((e) => e.fait).length;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link
            href="/pilotage/mon-equipe"
            className="rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800"
            aria-label="Retour à Mon équipe"
          >
            <ArrowLeft size={16} />
          </Link>
          <div>
            <h1 className="flex items-center gap-2 text-2xl font-bold">
              <Route size={22} className="text-brand dark:text-accent" /> Planning de {user.displayName}
            </h1>
            <p className="text-sm text-neutral-400">
              {user.poste ?? 'Chef de secteur'} · semaine du {WEEK_FMT.format(monday)} · {etapes.length} étape{etapes.length > 1 ? 's' : ''}
              {faites ? ` dont ${faites} faite${faites > 1 ? 's' : ''}` : ''}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-1.5">
          <Link href={`?semaine=${iso(prevMonday)}`} className="rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800" aria-label="Semaine précédente">
            <ChevronLeft size={15} />
          </Link>
          <Link href={`?semaine=${iso(nextMonday)}`} className="rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800" aria-label="Semaine suivante">
            <ChevronRight size={15} />
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {days.map((day) => (
          <section key={day.date} className="flex flex-col rounded-2xl bg-white shadow-card">
            <header className="flex items-baseline justify-between border-b border-neutral-100 px-3.5 py-2.5 dark:border-navy-700">
              <span className="text-sm font-semibold">{day.nom}</span>
              <span className="text-xs text-neutral-400">{day.label}</span>
            </header>
            <ul className="flex min-h-16 flex-col gap-1.5 p-2.5">
              {day.etapes.length === 0 ? (
                <li className="py-3 text-center text-xs text-neutral-300 dark:text-neutral-600">—</li>
              ) : (
                day.etapes.map((e) => {
                  const cible = e.client
                    ? { nom: e.client.enseigne, ville: e.client.ville, classe: e.client.niveauClass, prospect: false }
                    : { nom: e.prospect?.enseigne ?? '—', ville: e.prospect?.ville ?? null, classe: e.prospect?.niveauClass ?? null, prospect: true };
                  return (
                    <li key={e.id} className={`flex items-center gap-2 rounded-lg border px-2.5 py-2 ${e.fait ? 'border-emerald-200 bg-emerald-50/60 dark:border-emerald-900 dark:bg-emerald-950/20' : 'border-neutral-100 dark:border-navy-700'}`}>
                      {cible.prospect ? <Sprout size={13} className="shrink-0 text-violet-500" /> : <Store size={13} className="shrink-0 text-sky-500" />}
                      <ClassBadge value={cible.classe} size="xs" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-xs font-medium">{cible.nom}</p>
                        {cible.ville ? <p className="truncate text-[11px] text-neutral-400">{cible.ville}</p> : null}
                        {e.note ? <p className="truncate text-[11px] italic text-neutral-400">{e.note}</p> : null}
                      </div>
                      {e.fait ? <CheckCircle2 size={14} className="shrink-0 text-emerald-500" /> : null}
                    </li>
                  );
                })
              )}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
}
