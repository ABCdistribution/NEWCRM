import Link from 'next/link';
import { redirect } from 'next/navigation';
import { AlertCircle, CheckCircle2, ChevronLeft, ChevronRight, Repeat, Route } from 'lucide-react';
import { getMe, listMesPlannings, type PlanningItem } from '@/lib/api';
import { ClassBadge } from '@/components/class-badge';

export const metadata = { title: 'Mes visites — Selios' };

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const DAY_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

/** Lundi de la semaine contenant `d` (heure locale, à minuit). */
function mondayOf(d: Date): Date {
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dow = (monday.getDay() + 6) % 7; // 0 = lundi
  monday.setDate(monday.getDate() - dow);
  return monday;
}

/** yyyy-mm-dd en heure locale. */
function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** État visuel d'une visite : effectuée / manquée (passée non faite) / à venir. */
function statutVisite(v: PlanningItem, aujourdhui: string) {
  if (v.fait) return 'faite' as const;
  return iso(new Date(v.datePassage)) < aujourdhui ? ('manquee' as const) : ('prevue' as const);
}

const CHIP_STYLES = {
  faite: 'border-l-2 border-emerald-400 bg-emerald-500/15',
  manquee: 'border-l-2 border-red-400 bg-red-500/15',
  prevue: 'border-l-2 border-neutral-200 bg-neutral-50',
} as const;

export default async function TourneesPage({
  searchParams,
}: {
  searchParams: Promise<{ semaine?: string }>;
}) {
  const sp = await searchParams;
  const me = await getMe();
  if (!me) redirect('/login');

  const monday = mondayOf(sp.semaine ? new Date(sp.semaine) : new Date());
  const nextMonday = new Date(monday);
  nextMonday.setDate(nextMonday.getDate() + 7);
  const prevMonday = new Date(monday);
  prevMonday.setDate(prevMonday.getDate() - 7);
  const semaineIso = iso(monday);
  const aujourdhui = iso(new Date());
  const estSemaineCourante = iso(mondayOf(new Date())) === semaineIso;

  const days = JOURS.map((nom, idx) => {
    const d = new Date(monday);
    d.setDate(d.getDate() + idx);
    return { date: iso(d), nom, label: DAY_FMT.format(d) };
  });

  const plannings = await listMesPlannings(me.id, semaineIso, iso(nextMonday));

  // Visites par jour (clé = yyyy-mm-dd local).
  const parJour = new Map<string, PlanningItem[]>();
  for (const d of days) parJour.set(d.date, []);
  for (const p of plannings ?? []) {
    parJour.get(iso(new Date(p.datePassage)))?.push(p);
  }

  const faites = (plannings ?? []).filter((p) => p.fait).length;

  const navBtn =
    'inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-neutral-600 transition hover:bg-neutral-100';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Mes visites</h1>
        </div>

        {/* Navigation de semaine */}
        <div className="flex items-center gap-0.5 rounded-xl bg-white p-1 shadow-card">
          <Link href={`/tournees?semaine=${iso(prevMonday)}`} className={navBtn} aria-label="Semaine précédente">
            <ChevronLeft size={15} />
            Préc.
          </Link>
          <span className="min-w-40 px-1 text-center text-sm font-semibold text-brand">
            Sem. du {WEEK_FMT.format(monday)}
          </span>
          <Link href={`/tournees?semaine=${iso(nextMonday)}`} className={navBtn} aria-label="Semaine suivante">
            Suiv.
            <ChevronRight size={15} />
          </Link>
          {!estSemaineCourante ? (
            <Link
              href="/tournees"
              className="ml-1 rounded-xl bg-accent px-2.5 py-1.5 text-xs font-semibold text-brand transition hover:bg-accent/80"
            >
              Aujourd&apos;hui
            </Link>
          ) : null}
        </div>
      </div>

      {plannings === null ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Planning indisponible — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          {/* Légende + compteur */}
          <div className="flex flex-wrap items-center gap-4 text-xs text-neutral-500">
            <span className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm bg-emerald-400" />
              Effectuée
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm bg-red-400" />
              Manquée
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm border border-neutral-300 dark:border-navy-600" />
              À venir
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Repeat size={12} />
              Visite récurrente
            </span>
            <span className="ml-auto font-medium text-neutral-600">
              {faites}/{plannings.length} visite{plannings.length > 1 ? 's' : ''} effectuée{faites > 1 ? 's' : ''}
            </span>
          </div>

          {plannings.length === 0 ? (
            <div className="rounded-2xl bg-white p-10 text-center shadow-card">
              <Route size={32} className="mx-auto text-[#7D8CCE]" />
              <p className="mt-3 font-medium">Aucune visite planifiée cette semaine.</p>
              <p className="mt-1 text-sm text-neutral-400">
                Tes visites sont planifiées par ton chef de secteur.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto pb-2">
              <div className="grid min-w-[720px] grid-cols-5 items-start gap-2.5">
              {days.map((day) => {
                const visites = parJour.get(day.date) ?? [];
                const estAujourdhui = day.date === aujourdhui;
                return (
                  <section
                    key={day.date}
                    className={`flex min-h-40 flex-col rounded-2xl border bg-white shadow-card ${
                      estAujourdhui ? 'border-brand' : 'border-transparent'
                    }`}
                  >
                    <header className="flex items-baseline justify-between px-3 pb-1 pt-2.5">
                      <span className={`text-sm font-semibold ${estAujourdhui ? 'text-brand' : ''}`}>
                        {day.nom}
                      </span>
                      <span className="text-[11px] text-neutral-400">
                        {estAujourdhui ? 'auj.' : day.label}
                      </span>
                    </header>
                    <ul className="flex flex-1 flex-col gap-1.5 p-2 pt-1">
                      {visites.length === 0 ? (
                        <li className="flex flex-1 items-center justify-center text-xs text-neutral-500">
                          —
                        </li>
                      ) : (
                        visites.map((v) => {
                          const statut = statutVisite(v, aujourdhui);
                          return (
                            <li key={v.id}>
                              <Link
                                href={`/clients/${v.client.id}`}
                                className={`block rounded-lg px-2 py-1.5 transition hover:bg-accent/10 ${CHIP_STYLES[statut]}`}
                              >
                                <span className="flex items-center gap-1.5">
                                  {statut === 'faite' ? (
                                    <CheckCircle2 size={13} className="shrink-0 text-emerald-400" />
                                  ) : statut === 'manquee' ? (
                                    <AlertCircle size={13} className="shrink-0 text-red-400" />
                                  ) : null}
                                  <span className="min-w-0 flex-1 truncate text-xs font-medium">
                                    {v.client.enseigne.trim()}
                                  </span>
                                  {v.plannificationId ? (
                                    <Repeat size={11} className="shrink-0 text-neutral-400" />
                                  ) : null}
                                  <ClassBadge value={v.client.niveauClass} size="xs" />
                                </span>
                                {v.client.ville ? (
                                  <span className="mt-0.5 block truncate pl-0 text-[11px] text-neutral-400">
                                    {v.client.ville.trim()}
                                  </span>
                                ) : null}
                              </Link>
                            </li>
                          );
                        })
                      )}
                    </ul>
                  </section>
                );
              })}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
