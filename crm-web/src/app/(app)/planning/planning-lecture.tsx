import Link from 'next/link';
import { AlertCircle, CheckCircle2, ChevronLeft, ChevronRight, Repeat, Route } from 'lucide-react';
import { listMesPlannings, type PlanningItem } from '@/lib/api';
import { aujourdhuiParis, dateSemaine, mondayOf, iso, JOURS, JOURS_SEMAINE, DAY_FMT, WEEK_FMT } from '@/lib/planning-dates';
import { ClassBadge } from '@/components/class-badge';

/** Planning d'un promoteur (COMMERCIAL / ADV) : lecture seule, les visites sont planifiées par l'encadrement. */
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

export async function PlanningLecture({ userId, semaine }: { userId: string; semaine?: string }) {
  const monday = mondayOf(dateSemaine(semaine));
  const nextMonday = new Date(monday);
  nextMonday.setDate(nextMonday.getDate() + 7);
  const prevMonday = new Date(monday);
  prevMonday.setDate(prevMonday.getDate() - 7);
  const semaineIso = iso(monday);
  const aujourdhui = iso(aujourdhuiParis());
  const estSemaineCourante = iso(mondayOf(aujourdhuiParis())) === semaineIso;

  const semaineComplete = JOURS_SEMAINE.map((nom, idx) => {
    const d = new Date(monday);
    d.setDate(d.getDate() + idx);
    return { date: iso(d), nom, label: DAY_FMT.format(d) };
  });

  const plannings = await listMesPlannings(userId, semaineIso, iso(nextMonday));

  // Visites par jour (clé = yyyy-mm-dd local).
  const parJour = new Map<string, PlanningItem[]>();
  for (const d of semaineComplete) parJour.set(d.date, []);
  for (const p of plannings ?? []) {
    parJour.get(iso(new Date(p.datePassage)))?.push(p);
  }

  // Lundi → vendredi toujours ; samedi et dimanche seulement s'ils portent une visite (l'encadrement peut
  // planifier un samedi dans /planning-equipe). Les compteurs ne portent que sur les visites affichées.
  const days = semaineComplete.filter((d, idx) => idx < JOURS.length || (parJour.get(d.date)?.length ?? 0) > 0);
  const affichees = days.flatMap((d) => parJour.get(d.date) ?? []);
  const faites = affichees.filter((p) => p.fait).length;

  const navBtn =
    'inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-neutral-600 transition hover:bg-neutral-100';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Mon planning</h1>
        </div>

        {/* Navigation de semaine */}
        <div className="flex items-center gap-0.5 rounded-xl bg-white p-1 shadow-card">
          <Link href={`/planning?semaine=${iso(prevMonday)}`} className={navBtn} aria-label="Semaine précédente">
            <ChevronLeft size={15} />
            Préc.
          </Link>
          <span className="min-w-40 px-1 text-center text-sm font-semibold text-brand">
            Sem. du {WEEK_FMT.format(monday)}
          </span>
          <Link href={`/planning?semaine=${iso(nextMonday)}`} className={navBtn} aria-label="Semaine suivante">
            Suiv.
            <ChevronRight size={15} />
          </Link>
          {!estSemaineCourante ? (
            <Link
              href="/planning"
              className="ml-1 rounded-xl bg-brand px-2.5 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90"
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
              {faites}/{affichees.length} visite{affichees.length > 1 ? 's' : ''} effectuée{faites > 1 ? 's' : ''}
            </span>
          </div>

          {affichees.length === 0 ? (
            <div className="rounded-2xl bg-white p-10 text-center shadow-card">
              <Route size={32} className="mx-auto text-accent" />
              <p className="mt-3 font-medium">Aucune visite planifiée cette semaine.</p>
              <p className="mt-1 text-sm text-neutral-400">
                Tes visites sont planifiées par ton chef de secteur.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto px-1 pb-2 pt-1">
              <div
                className="grid items-start gap-2.5"
                style={{ gridTemplateColumns: `repeat(${days.length}, minmax(0, 1fr))`, minWidth: `${days.length * 144}px` }}
              >
              {days.map((day) => {
                const visites = parJour.get(day.date) ?? [];
                // Jour courant : `ring` et non `border` (`.shadow-card`, hors couche Tailwind, impose sa propre bordure).
                const estAujourdhui = day.date === aujourdhui;
                return (
                  <section
                    key={day.date}
                    className={`flex min-h-40 flex-col rounded-2xl bg-white shadow-card ${
                      estAujourdhui ? 'ring-2 ring-brand' : ''
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
