'use client';

import { useId, useMemo, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { AlertCircle, BellRing, CheckCircle2, Plus, Repeat, Store, Trash2, X } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { CARTE, FOCUS } from './equipe-ui';
import { ajouterVisite, deplacerVisite, relancerVisite, supprimerVisite } from '@/lib/planning-equipe-actions';
import { aujourdhuiParis } from '@/lib/planning-dates';

export type VisiteJour = { id: string; clientId: string; clientNom: string; ville: string | null; classe: string | null; fait: boolean; recurrente: boolean };
export type JourPlanning = { nom: string; libelle: string; date: string; visites: VisiteJour[] };
export type ClientChoix = { id: string; enseigne: string; ville: string | null; codeAs400: string };

function dateLocale(): string {
  const d = aujourdhuiParis();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const CHAMP = `rounded-lg border border-neutral-200 bg-white px-2.5 py-2 text-sm dark:border-navy-700 dark:bg-navy-950 ${FOCUS}`;
const BTN_PRIMAIRE = `inline-flex items-center justify-center gap-1.5 rounded-lg bg-brand px-3 py-2 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50 ${FOCUS}`;

/** Sélecteur de promoteur : met à jour `?promoteur=` (et conserve la semaine). */
export function SelecteurPromoteur({ promoteurs, valeur, semaine }: { promoteurs: { id: string; nom: string }[]; valeur: string; semaine: string }) {
  const router = useRouter();
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-xs font-semibold uppercase tracking-wide text-neutral-400">
        Promoteur
      </label>
      <select
        id={id}
        value={valeur}
        onChange={(e) => router.push(`/planning-equipe?promoteur=${encodeURIComponent(e.target.value)}&semaine=${encodeURIComponent(semaine)}`, { scroll: false })}
        className={`w-full rounded-xl py-2.5 shadow-card sm:max-w-md ${CHAMP}`}
      >
        {promoteurs.map((p) => (
          <option key={p.id} value={p.id}>
            {p.nom}
          </option>
        ))}
      </select>
    </div>
  );
}

/** Formulaire d'ajout d'une visite pour un jour : recherche (enseigne, ville, code) puis choix du client. */
function AjoutVisite({ promoteurId, date, clients, dejaPlanifies, onErreur }: { promoteurId: string; date: string; clients: ClientChoix[]; dejaPlanifies: ReadonlySet<string>; onErreur: (m: string | null) => void }) {
  const [ouvert, setOuvert] = useState(false);
  const [recherche, setRecherche] = useState('');
  const [clientId, setClientId] = useState('');
  const [enCours, demarrer] = useTransition();
  const idRecherche = useId();
  const idClient = useId();

  const filtres = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    const liste = q ? clients.filter((c) => `${c.enseigne} ${c.ville ?? ''} ${c.codeAs400}`.toLowerCase().includes(q)) : clients;
    return liste.slice(0, 200);
  }, [clients, recherche]);

  if (!ouvert) {
    return (
      <button type="button" onClick={() => setOuvert(true)} className={`flex w-full items-center justify-center gap-1 rounded-lg border border-dashed border-neutral-300 px-2 py-2 text-xs font-medium text-neutral-500 transition hover:border-brand hover:text-brand dark:border-navy-700 ${FOCUS}`}>
        <Plus size={14} aria-hidden /> Ajouter une visite
      </button>
    );
  }

  function valider() {
    if (!clientId) {
      onErreur('Choisissez un client.');
      return;
    }
    onErreur(null);
    demarrer(async () => {
      const r = await ajouterVisite(promoteurId, clientId, date);
      if (r.error) onErreur(r.error);
      else {
        setOuvert(false);
        setRecherche('');
        setClientId('');
      }
    });
  }

  return (
    <div className="flex flex-col gap-2 rounded-lg bg-neutral-50 p-2 dark:bg-navy-800">
      <label htmlFor={idRecherche} className="sr-only">Rechercher un client</label>
      <input id={idRecherche} type="search" value={recherche} onChange={(e) => setRecherche(e.target.value)} placeholder="Rechercher un client…" className={CHAMP} />
      <label htmlFor={idClient} className="sr-only">Client à visiter</label>
      <select id={idClient} value={clientId} onChange={(e) => setClientId(e.target.value)} className={CHAMP}>
        <option value="">{filtres.length === 0 ? 'Aucun client trouvé' : `Choisir un client (${filtres.length})`}</option>
        {filtres.map((c) => (
          <option key={c.id} value={c.id}>
            {c.enseigne}
            {c.ville ? ` — ${c.ville}` : ''}
            {dejaPlanifies.has(c.id) ? ' (déjà planifié cette semaine)' : ''}
          </option>
        ))}
      </select>
      <div className="flex gap-2">
        <button type="button" onClick={valider} disabled={enCours} className={`flex-1 ${BTN_PRIMAIRE}`}>
          {enCours ? 'Ajout…' : 'Ajouter'}
        </button>
        <button type="button" onClick={() => { setOuvert(false); onErreur(null); }} className={`rounded-lg border border-neutral-200 px-2.5 text-neutral-500 dark:border-navy-700 ${FOCUS}`} aria-label="Annuler l'ajout">
          <X size={15} aria-hidden />
        </button>
      </div>
    </div>
  );
}

/** Une visite : changement de jour et suppression (une visite déjà faite reste en lecture). */
function LigneVisite({ v, jours, dateCourante, aujourdhui, onErreur, onInfo }: { v: VisiteJour; jours: JourPlanning[]; dateCourante: string; aujourdhui: string; onErreur: (m: string | null) => void; onInfo: (m: string | null) => void }) {
  const manquee = !v.fait && dateCourante < aujourdhui;
  const [enCours, demarrer] = useTransition();
  const [confirme, setConfirme] = useState(false);
  const idJour = useId();

  return (
    <li className={`flex flex-col gap-2 rounded-lg border px-2.5 py-2 ${v.fait ? 'border-emerald-200 bg-emerald-50/60 dark:border-emerald-900 dark:bg-emerald-950/20' : 'border-neutral-100 dark:border-navy-700'} ${enCours ? 'opacity-60' : ''}`}>
      <div className="flex items-center gap-2">
        <Store size={13} className="shrink-0 text-brand" aria-hidden />
        {v.classe ? <ClassBadge value={v.classe} size="xs" /> : null}
        <div className="min-w-0 flex-1">
          <p className="truncate text-xs font-medium">{v.clientNom}</p>
          {v.ville ? <p className="truncate text-[11px] text-neutral-400">{v.ville}</p> : null}
        </div>
        {v.recurrente ? <Repeat size={12} className="shrink-0 text-neutral-400" aria-label="Visite récurrente" /> : null}
        {v.fait ? <CheckCircle2 size={14} className="shrink-0 text-emerald-500" aria-label="Visite faite" /> : null}
        {manquee ? <AlertCircle size={14} className="shrink-0 text-red-500" aria-label="Visite manquée" /> : null}
      </div>
      {v.fait ? null : (
        <div className="flex flex-wrap items-center gap-1.5">
          {manquee ? (
            <button
              type="button"
              disabled={enCours}
              onClick={() => {
                onErreur(null);
                onInfo(null);
                demarrer(async () => {
                  const r = await relancerVisite(v.id);
                  if (r.error) onErreur(r.error);
                  else onInfo(`Relance envoyée au promoteur pour ${v.clientNom}.`);
                });
              }}
              className={`inline-flex items-center gap-1 rounded-lg bg-brand px-2 py-1 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-50 ${FOCUS}`}
              aria-label={`Relancer le promoteur pour ${v.clientNom}`}
              title="Envoyer une notification de relance au promoteur"
            >
              <BellRing size={12} aria-hidden /> Relancer
            </button>
          ) : null}
          <label htmlFor={idJour} className="sr-only">Déplacer la visite chez {v.clientNom}</label>
          <select
            id={idJour}
            value={dateCourante}
            disabled={enCours}
            onChange={(e) => {
              onErreur(null);
              const date = e.target.value;
              demarrer(async () => {
                const r = await deplacerVisite(v.id, date);
                if (r.error) onErreur(r.error);
              });
            }}
            className={`min-w-0 flex-1 py-1 text-xs ${CHAMP}`}
          >
            {jours.map((j) => (
              <option key={j.date} value={j.date}>
                {j.nom} {j.libelle}
              </option>
            ))}
          </select>
          {confirme ? (
            <>
              <button
                type="button"
                disabled={enCours}
                onClick={() => {
                  onErreur(null);
                  demarrer(async () => {
                    const r = await supprimerVisite(v.id);
                    if (r.error) onErreur(r.error);
                    setConfirme(false);
                  });
                }}
                className={`rounded-lg bg-red-600 px-2 py-1 text-xs font-medium text-white ${FOCUS}`}
              >
                Retirer
              </button>
              <button type="button" onClick={() => setConfirme(false)} className={`rounded-lg border border-neutral-200 px-2 py-1 text-xs dark:border-navy-700 ${FOCUS}`}>
                Non
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={() => setConfirme(true)}
              className={`rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/40 ${FOCUS}`}
              aria-label={`Supprimer la visite chez ${v.clientNom}`}
              title="Supprimer la visite"
            >
              <Trash2 size={14} aria-hidden />
            </button>
          )}
        </div>
      )}
    </li>
  );
}

/** Grille de la semaine d'un promoteur : une carte par jour, avec ajout / déplacement / suppression. */
export function PlanningEquipeBoard({ promoteurId, jours, clients }: { promoteurId: string; jours: JourPlanning[]; clients: ClientChoix[] }) {
  const [erreur, setErreur] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const aujourdhui = dateLocale();
  // Clients déjà planifiés cette semaine (repère dans la liste d'ajout) et totaux de la semaine.
  const dejaPlanifies = useMemo(() => new Set(jours.flatMap((j) => j.visites.map((v) => v.clientId))), [jours]);
  const total = jours.reduce((n, j) => n + j.visites.length, 0);
  const faites = jours.reduce((n, j) => n + j.visites.filter((v) => v.fait).length, 0);
  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-neutral-600">
        <span className="font-semibold">
          {total} visite{total > 1 ? 's' : ''} planifiée{total > 1 ? 's' : ''} cette semaine
          {total > 0 ? ` (${faites} effectuée${faites > 1 ? 's' : ''})` : ''}
        </span>
        <span className="inline-flex items-center gap-1.5">
          <CheckCircle2 size={13} className="text-emerald-600" aria-hidden /> Effectuée
        </span>
        <span className="inline-flex items-center gap-1.5">
          <AlertCircle size={13} className="text-red-600" aria-hidden /> Manquée
        </span>
        <span className="inline-flex items-center gap-1.5">
          <Repeat size={13} className="text-neutral-500" aria-hidden /> Récurrente
        </span>
      </div>
      {info ? (
        <p role="status" className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
          {info}
        </p>
      ) : null}
      {erreur ? (
        <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900 dark:bg-red-950/30 dark:text-red-300">
          {erreur}
        </p>
      ) : null}
      {/* Jour courant : `ring` et non `border` (`.shadow-card`, hors couche Tailwind, impose sa propre bordure). */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {jours.map((j) => (
          <section key={j.date} className={`flex flex-col ${CARTE} ${j.date === aujourdhui ? 'ring-2 ring-brand' : ''}`} aria-label={`${j.nom} ${j.libelle}${j.date === aujourdhui ? " (aujourd'hui)" : ''}`}>
            <header className="flex items-baseline justify-between border-b border-neutral-100 px-3.5 py-2.5 dark:border-navy-700">
              <span className={`text-sm font-semibold ${j.date === aujourdhui ? 'text-brand' : ''}`}>{j.nom}</span>
              <span className="text-xs text-neutral-500">{j.date === aujourdhui ? `${j.libelle} · auj.` : j.libelle}</span>
            </header>
            <div className="flex flex-col gap-2 p-2.5">
              {j.visites.length === 0 ? <p className="py-2 text-center text-xs text-neutral-400">Aucune visite</p> : null}
              {j.visites.length > 0 ? (
                <ul className="flex flex-col gap-1.5">
                  {j.visites.map((v) => (
                    <LigneVisite key={v.id} v={v} jours={jours} dateCourante={j.date} aujourdhui={aujourdhui} onErreur={setErreur} onInfo={setInfo} />
                  ))}
                </ul>
              ) : null}
              <AjoutVisite promoteurId={promoteurId} date={j.date} clients={clients} dejaPlanifies={dejaPlanifies} onErreur={setErreur} />
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
