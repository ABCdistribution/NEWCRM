'use client';

import Link from 'next/link';
import { useState, useTransition } from 'react';
import { BadgeCheck, ChevronLeft, ChevronRight, Hourglass, Lock, Save, X } from 'lucide-react';
import { KpiTile } from './kpi-tile';
import { LignesParJour } from './tournee-prevue';
import { ROLE_LABELS } from './badges';
import { chargerRapportDetail } from '@/lib/rapports-actions';
import { FUSEAU } from '@/lib/planning-dates';
import type { RapportAuteur, RapportDetail, RapportsListe, StatutRapport } from '@/lib/api';

const WEEK_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
// Heure affichée À PARIS (fuseau de la plateforme) : le HTML rendu par le serveur et celui du navigateur concordent.
// WEEK_FMT n'affiche qu'un jour, tiré d'une date « locale » (minuit) : lui donner un fuseau décalerait le jour.
const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { timeZone: FUSEAU, day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

function isoToDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  // Garde-fou : une date illisible ferait lever « Invalid time value » à Intl pendant le rendu ; on retombe sur aujourd'hui.
  return Number.isNaN(date.getTime()) ? new Date() : date;
}
function decaler(iso: string, jours: number): string {
  const d = isoToDate(iso);
  d.setDate(d.getDate() + jours);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const STATUTS: Record<StatutRapport, { libelle: string; classe: string; icone: React.ReactNode }> = {
  PREVISION_A_SAISIR: { libelle: 'Prévision à saisir', classe: 'bg-neutral-500/10 text-neutral-700', icone: null },
  PREVISION_ENREGISTREE: { libelle: 'Prévision enregistrée', classe: 'bg-sky-500/12 text-sky-800', icone: <Save size={12} /> },
  EN_COURS: { libelle: 'Rapport en cours', classe: 'bg-amber-500/12 text-amber-800', icone: <Hourglass size={12} /> },
  VALIDE: { libelle: 'Validé', classe: 'bg-emerald-500/12 text-emerald-800', icone: <BadgeCheck size={12} /> },
  VALIDE_AUTO: { libelle: 'Validé auto', classe: 'bg-brand/10 text-navy', icone: <Lock size={12} /> },
};

function Statut({ statut }: { statut: StatutRapport }) {
  const s = STATUTS[statut];
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ${s.classe}`}>
      {s.icone}
      {s.libelle}
    </span>
  );
}

/**
 * Consultation des rapports d'activité hebdomadaires des chefs de secteur et directeurs régionaux (lecture seule).
 * Pour chaque auteur : tournée prévue (photographie figée dès le mardi), tournée réalisée, et rapport validé
 * (« Validé auto » quand la clôture automatique du lundi à 4 h l'a clôturé).
 */
export function RapportsBoard({ data, semaine, nonDisponible }: { data: RapportsListe | null; semaine: string; nonDisponible?: boolean }) {
  const [detail, setDetail] = useState<RapportDetail | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, start] = useTransition();

  const ouvrir = (a: RapportAuteur) =>
    start(async () => {
      setErreur(null);
      try {
        const r = await chargerRapportDetail(a.userId, semaine);
        if (r.detail) setDetail(r.detail);
        else setErreur(r.error);
      } catch {
        // Rejet de la requête elle-même (session expirée, API ou réseau indisponible).
        setErreur('Rapport indisponible (session expirée ou API injoignable). Rechargez la page.');
      }
    });

  const auteurs = data?.auteurs ?? [];
  const nb = (...st: StatutRapport[]) => auteurs.filter((a) => st.includes(a.statut)).length;
  const navBtn =
    'inline-flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-neutral-500 transition hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-accent/20';

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold">Rapports d&apos;activité</h1>
        <div className="flex items-center gap-0.5 rounded-xl bg-white p-1 shadow-card">
          <Link href={`/rapports?semaine=${decaler(semaine, -7)}`} className={navBtn} aria-label="Semaine précédente">
            <ChevronLeft size={15} /> Préc.
          </Link>
          <span className="min-w-44 px-1 text-center text-sm font-semibold text-brand dark:text-accent">
            Sem. du {WEEK_FMT.format(isoToDate(semaine))}
          </span>
          <Link href={`/rapports?semaine=${decaler(semaine, 7)}`} className={navBtn} aria-label="Semaine suivante">
            Suiv. <ChevronRight size={15} />
          </Link>
        </div>
      </div>

      {nonDisponible || !data ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Rapports indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <>
          <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <KpiTile label="Auteurs" value={String(auteurs.length)} />
            <KpiTile label="Validés" value={String(nb('VALIDE', 'VALIDE_AUTO'))} />
            <KpiTile label="Rapports en cours" value={String(nb('EN_COURS'))} />
            <KpiTile label="Prévisions à saisir" value={String(nb('PREVISION_A_SAISIR'))} />
          </section>

          {erreur ? <p role="alert" className="text-sm text-red-600">{erreur}</p> : null}

          <div className="overflow-x-auto rounded-xl bg-white shadow-card">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500">
                <tr>
                  <th className="px-3 py-2.5 font-medium">Auteur</th>
                  <th className="px-3 py-2.5 font-medium">Région / Secteur</th>
                  <th className="px-3 py-2.5 font-medium">Prévue</th>
                  <th className="px-3 py-2.5 font-medium">Réalisée</th>
                  <th className="px-3 py-2.5 font-medium">Rapport</th>
                  <th className="px-3 py-2.5" />
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {auteurs.map((a) => (
                  <tr key={a.userId} className="hover:bg-neutral-50">
                    <td className="px-3 py-2.5">
                      <p className="font-medium">{a.nom}</p>
                      <p className="text-xs text-neutral-400">{ROLE_LABELS[a.role] ?? a.role}</p>
                    </td>
                    <td className="px-3 py-2.5 text-neutral-500">{[a.region, a.secteur].filter(Boolean).join(' · ') || '—'}</td>
                    <td className="px-3 py-2.5 text-neutral-500">
                      {a.previsionNonRenseignee
                        ? 'Non renseignée'
                        : a.prevuAt
                          ? `${a.nbPrevues ?? 0} lignes · ${DATE_FMT.format(new Date(a.prevuAt))}`
                          : '—'}
                    </td>
                    <td className="px-3 py-2.5 text-neutral-500">
                      {a.nbRealisees} ligne{a.nbRealisees > 1 ? 's' : ''}
                      {a.nbRealisees > 0 ? ` · ${a.nbFaites} faite${a.nbFaites > 1 ? 's' : ''}` : ''}
                    </td>
                    <td className="px-3 py-2.5">
                      <Statut statut={a.statut} />
                      {a.valideAt ? <p className="mt-0.5 text-[11px] text-neutral-400">le {DATE_FMT.format(new Date(a.valideAt))}</p> : null}
                    </td>
                    <td className="px-3 py-2.5 text-right">
                      <button
                        type="button"
                        onClick={() => ouvrir(a)}
                        disabled={pending}
                        className="rounded-lg px-2.5 py-1 text-xs font-semibold text-brand transition hover:bg-neutral-100 disabled:opacity-40 dark:text-accent dark:hover:bg-accent/20"
                      >
                        Voir
                      </button>
                    </td>
                  </tr>
                ))}
                {auteurs.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">
                      Aucun chef de secteur ni directeur régional dans votre périmètre.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </>
      )}

      {detail ? (
        <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-16" onClick={() => setDetail(null)}>
          <div className="w-full max-w-4xl rounded-2xl bg-white p-5 shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
            <div className="mb-4 flex items-start justify-between gap-3">
              <div>
                <h2 className="text-lg font-bold">{detail.auteur.displayName}</h2>
                <p className="text-xs text-neutral-400">Semaine du {WEEK_FMT.format(isoToDate(semaine))}</p>
              </div>
              <div className="flex items-center gap-3">
                <Statut statut={detail.etat.statut} />
                <button type="button" onClick={() => setDetail(null)} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
                  <X size={18} />
                </button>
              </div>
            </div>
            <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
              <section>
                <h3 className="pb-2 text-sm font-semibold">
                  Tournée prévue <span className="font-normal text-neutral-400">(figée dès le mardi)</span>
                </h3>
                <LignesParJour lignes={detail.prevue ?? []} vide="Prévision non renseignée." />
              </section>
              <section>
                <h3 className="pb-2 text-sm font-semibold">
                  {detail.etat.verrouillee ? 'Rapport validé' : 'Tournée réalisée'}{' '}
                  <span className="font-normal text-neutral-400">
                    {detail.etat.verrouillee ? '(définitif)' : '(modifiable jusqu’à la validation)'}
                  </span>
                </h3>
                <LignesParJour lignes={detail.realisee} vide="Aucune ligne saisie." />
              </section>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
