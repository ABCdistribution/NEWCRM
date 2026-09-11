import Link from 'next/link';
import { ChevronLeft, ChevronRight, Route } from 'lucide-react';
import { listUsers, listPlannings, listClientsOfRepr, listRegles } from '@/lib/api';
import { PromoteurSelect } from '@/components/promoteur-select';
import { PlanningBoard } from '@/components/planning-board';
import { RecurrenceCard } from '@/components/recurrence-card';

export const metadata = { title: 'Planification tournées — Helios' };

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
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

export default async function TourneesPage({
  searchParams,
}: {
  searchParams: Promise<{ promoteur?: string; semaine?: string }>;
}) {
  const sp = await searchParams;

  // Promoteurs planifiables : commerciaux actifs reliés à un code représentant.
  const usersRes = await listUsers({ role: 'COMMERCIAL', page: 1 }).catch(() => null);
  const promoteurs = (usersRes?.data ?? []).filter((u) => u.isActive && u.idRepr);

  const promoteurId =
    sp.promoteur && promoteurs.some((p) => p.id === sp.promoteur) ? sp.promoteur : promoteurs[0]?.id;
  const promoteur = promoteurs.find((p) => p.id === promoteurId);

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

  const [plannings, portefeuille, regles] = promoteur
    ? await Promise.all([
        listPlannings(promoteur.id, semaineIso, iso(nextMonday)),
        listClientsOfRepr(promoteur.idRepr!),
        listRegles(promoteur.id),
      ])
    : [null, [], null];

  const navBtn =
    'inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-neutral-300 transition hover:bg-accent/20';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Planification des tournées</h1>
          <p className="text-sm text-neutral-500">
            Glisse un magasin du portefeuille vers un jour — ou déplace une visite d&apos;un jour à
            l&apos;autre. Visible dans kratos et sur l&apos;app mobile.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {promoteurs.length > 0 ? (
            <PromoteurSelect promoteurs={promoteurs} value={promoteurId!} semaine={semaineIso} />
          ) : null}
          <div className="flex items-center gap-0.5 rounded-xl bg-white p-1 shadow-card">
            <Link
              href={`/tournees?promoteur=${promoteurId}&semaine=${iso(prevMonday)}`}
              className={navBtn}
              aria-label="Semaine précédente"
            >
              <ChevronLeft size={15} />
              Préc.
            </Link>
            <span className="min-w-40 px-1 text-center text-sm font-semibold text-brand dark:text-accent">
              Sem. du {WEEK_FMT.format(monday)}
            </span>
            <Link
              href={`/tournees?promoteur=${promoteurId}&semaine=${iso(nextMonday)}`}
              className={navBtn}
              aria-label="Semaine suivante"
            >
              Suiv.
              <ChevronRight size={15} />
            </Link>
            {!estSemaineCourante ? (
              <Link
                href={`/tournees?promoteur=${promoteurId}`}
                className="ml-1 rounded-xl bg-accent px-2.5 py-1.5 text-xs font-semibold text-brand transition hover:bg-accent/80"
              >
                Aujourd&apos;hui
              </Link>
            ) : null}
          </div>
        </div>
      </div>

      {promoteurs.length === 0 ? (
        <div className="rounded-2xl bg-white p-10 text-center shadow-card">
          <Route size={32} className="mx-auto text-[#A78BDA]" />
          <p className="mt-3 font-medium">Aucun promoteur planifiable.</p>
          <p className="mt-1 text-sm text-neutral-400">
            Il faut des commerciaux actifs reliés à un code représentant (synchronisé depuis
            l&apos;AD à leur connexion).
          </p>
        </div>
      ) : plannings === null ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Planning indisponible — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          <p className="text-sm text-neutral-500">
            <span className="font-medium">{promoteur!.displayName}</span> · {plannings.length} visite
            {plannings.length > 1 ? 's' : ''} planifiée{plannings.length > 1 ? 's' : ''} cette semaine
          </p>
          <RecurrenceCard
            promoteurId={promoteur!.id}
            semaineIso={semaineIso}
            regles={regles ?? []}
            portefeuille={portefeuille}
          />
          <PlanningBoard
            promoteurId={promoteur!.id}
            days={days}
            plannings={plannings}
            portefeuille={portefeuille}
          />
        </>
      )}
    </div>
  );
}
