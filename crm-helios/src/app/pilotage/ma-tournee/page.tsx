import Link from 'next/link';
import { ChevronLeft, ChevronRight, Route, Sprout, Store } from 'lucide-react';
import { getMe, getSemaineEtat, listMaTournee, listMagasinsGeo, listProspects, type ProspectRow } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { MaTourneeBoard } from '@/components/ma-tournee-board';
import { PlanningValidation } from '@/components/planning-validation';
import { OutlookSyncButton } from '@/components/outlook-sync-button';

export const metadata = { title: "Mon planning d'activité — Helios" };

// La tournée personnelle concerne l'encadrement (prospection + suivi magasins).
const ALLOWED = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADMIN'];

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
const DAY_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

/** Lundi de la semaine contenant `d` (heure locale, à minuit). */
function mondayOf(d: Date): Date {
  const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return monday;
}

/** yyyy-mm-dd en heure locale. */
function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export default async function MaTourneePage({
  searchParams,
}: {
  searchParams: Promise<{ semaine?: string }>;
}) {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;

  const sp = await searchParams;
  const monday = mondayOf(sp.semaine ? new Date(sp.semaine) : new Date());
  const nextMonday = new Date(monday);
  nextMonday.setDate(nextMonday.getDate() + 7);
  const prevMonday = new Date(monday);
  prevMonday.setDate(prevMonday.getDate() - 7);
  const semaineIso = iso(monday);
  const estSemaineCourante = iso(mondayOf(new Date())) === semaineIso;

  const days = JOURS.map((nom, idx) => {
    const d = new Date(monday);
    d.setDate(d.getDate() + idx);
    return { date: iso(d), nom, label: DAY_FMT.format(d) };
  });

  const [etapes, magasins, semaineEtat] = await Promise.all([
    listMaTournee(semaineIso, iso(nextMonday)),
    listMagasinsGeo(),
    getSemaineEtat(semaineIso),
  ]);

  // Mes prospects encore en jeu (à glisser dans la tournée).
  const prospects: ProspectRow[] = [];
  try {
    for (let pg = 1; pg <= 5; pg++) {
      const res = await listProspects({ page: pg });
      prospects.push(...res.data.filter((x) => !x.clientId && x.statut !== 'PERDU' && x.statut !== 'GAGNE'));
      if (pg * res.limit >= res.total) break;
    }
  } catch {
    // panneau prospects vide si l'API prospection est indisponible
  }

  const navBtn =
    'inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-neutral-500 transition hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-accent/20';

  const prospections = (etapes ?? []).filter((e) => e.prospect).length;
  const suivis = (etapes ?? []).filter((e) => e.client).length;
  const faites = (etapes ?? []).filter((e) => e.fait).length;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold">
            <Route size={22} className="text-brand dark:text-accent" /> Mon planning d'activité
          </h1>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <OutlookSyncButton />
          <PlanningValidation
            semaine={semaineIso}
            nbEtapes={(etapes ?? []).length}
            prevuAt={semaineEtat?.prevuAt ?? null}
            valideAt={semaineEtat?.valideAt ?? null}
          />
        </div>
        <div className="flex items-center gap-0.5 rounded-xl bg-white p-1 shadow-card">
          <Link href={`/pilotage/ma-tournee?semaine=${iso(prevMonday)}`} className={navBtn} aria-label="Semaine précédente">
            <ChevronLeft size={15} />
            Préc.
          </Link>
          <span className="min-w-40 px-1 text-center text-sm font-semibold text-brand dark:text-accent">
            Sem. du {WEEK_FMT.format(monday)}
          </span>
          <Link href={`/pilotage/ma-tournee?semaine=${iso(nextMonday)}`} className={navBtn} aria-label="Semaine suivante">
            Suiv.
            <ChevronRight size={15} />
          </Link>
          {!estSemaineCourante ? (
            <Link
              href="/pilotage/ma-tournee"
              className="ml-1 rounded-xl bg-brand px-2.5 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
            >
              Aujourd&apos;hui
            </Link>
          ) : null}
        </div>
      </div>

      {etapes === null ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Tournée indisponible — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          {/* Légende + compteurs */}
          <div className="flex flex-wrap items-center gap-4 text-xs text-neutral-500">
            <span className="inline-flex items-center gap-1.5">
              <Sprout size={13} className="text-violet-500" /> Prospection
              <b>{prospections}</b>
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Store size={13} className="text-sky-500" /> Suivi magasin
              <b>{suivis}</b>
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm bg-emerald-400" /> Faites
              <b>{faites}</b> / {etapes.length}
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-sm bg-red-400" /> En retard
            </span>
          </div>

          <MaTourneeBoard days={days} etapes={etapes} magasins={magasins ?? []} prospects={prospects} />
        </>
      )}
    </div>
  );
}
