'use client';

import { useId, useMemo, useState, useTransition } from 'react';
import { Plus, Repeat, Trash2, X } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { FOCUS } from './equipe-ui';
import { creerRegle, supprimerRegle } from '@/lib/planning-equipe-actions';
import type { RegleRecurrence } from '@/lib/api';

export type ClientRegle = { id: string; enseigne: string; ville: string | null; niveauClass: string | null };

const JOURS_COURTS = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const FREQUENCES = [
  { value: 1, label: 'Chaque semaine' },
  { value: 2, label: 'Toutes les 2 semaines' },
  { value: 3, label: 'Toutes les 3 semaines' },
  { value: 4, label: 'Toutes les 4 semaines' },
];

const CHAMP = `rounded-lg border border-neutral-200 bg-white px-2.5 py-2 text-sm dark:border-navy-700 dark:bg-navy-950 ${FOCUS}`;

function libelleJours(csv: string): string {
  return csv
    .split(',')
    .map((s) => JOURS_COURTS[Number(s) - 1])
    .filter(Boolean)
    .join(', ');
}

function libelleFrequence(rec: number): string {
  return rec === 1 ? 'chaque semaine' : `toutes les ${rec} semaines`;
}

/** Règles de récurrence d'un promoteur : le serveur génère les visites des semaines à venir. */
export function RecurrenceCard({
  promoteurId,
  semaineIso,
  regles,
  portefeuille,
}: {
  promoteurId: string;
  semaineIso: string; // lundi affiché : ancre par défaut des nouvelles règles
  regles: RegleRecurrence[];
  portefeuille: ClientRegle[];
}) {
  const [ouvert, setOuvert] = useState(false);
  const [recherche, setRecherche] = useState('');
  const [clientId, setClientId] = useState('');
  const [jours, setJours] = useState<number[]>([]);
  const [frequence, setFrequence] = useState(1);
  const [erreur, setErreur] = useState<string | null>(null);
  const [enCours, demarrer] = useTransition();
  const idRecherche = useId();
  const idClient = useId();
  const idFreq = useId();

  const dejaRegle = useMemo(() => new Set(regles.map((r) => r.client.id)), [regles]);
  const filtres = useMemo(() => {
    const q = recherche.trim().toLowerCase();
    return portefeuille
      .filter((c) => !dejaRegle.has(c.id) && (!q || `${c.enseigne} ${c.ville ?? ''}`.toLowerCase().includes(q)))
      .slice(0, 200);
  }, [portefeuille, recherche, dejaRegle]);

  function fermer() {
    setOuvert(false);
    setRecherche('');
    setClientId('');
    setJours([]);
    setFrequence(1);
    setErreur(null);
  }

  function creer() {
    if (!clientId) return setErreur('Choisissez un client.');
    if (jours.length === 0) return setErreur('Cochez au moins un jour.');
    setErreur(null);
    demarrer(async () => {
      const r = await creerRegle({ promoteurId, clientId, jours, recurrence: frequence, dateDebut: semaineIso });
      if (r.error) setErreur(r.error);
      else fermer();
    });
  }

  function retirer(id: string) {
    setErreur(null);
    demarrer(async () => {
      const r = await supprimerRegle(id);
      if (r.error) setErreur(r.error);
    });
  }

  return (
    <section className="rounded-2xl bg-white shadow-card" aria-label="Clients récurrents">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-4 py-2.5 text-sm font-semibold dark:border-navy-700">
        <Repeat size={15} className="text-brand dark:text-accent" aria-hidden />
        Clients récurrents
        <span className="rounded-full bg-brand/10 px-2 py-0.5 text-xs font-semibold text-brand dark:bg-accent/10 dark:text-accent">
          {regles.length}
        </span>
        <button
          type="button"
          onClick={() => (ouvert ? fermer() : setOuvert(true))}
          aria-expanded={ouvert}
          className={`ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium transition hover:border-brand hover:text-brand dark:border-navy-700 dark:hover:border-accent dark:hover:text-accent ${FOCUS}`}
        >
          {ouvert ? <X size={12} aria-hidden /> : <Plus size={12} aria-hidden />}
          {ouvert ? 'Fermer' : 'Ajouter'}
        </button>
      </h2>

      {ouvert ? (
        <div className="flex flex-col gap-3 border-b border-neutral-100 px-4 py-3 dark:border-navy-700">
          <div className="grid gap-2 sm:grid-cols-2">
            <div className="flex flex-col gap-1">
              <label htmlFor={idRecherche} className="text-xs text-neutral-500">Rechercher un client</label>
              <input id={idRecherche} type="search" value={recherche} onChange={(e) => setRecherche(e.target.value)} placeholder="Enseigne ou ville…" className={CHAMP} />
            </div>
            <div className="flex flex-col gap-1">
              <label htmlFor={idClient} className="text-xs text-neutral-500">Client</label>
              <select id={idClient} value={clientId} onChange={(e) => setClientId(e.target.value)} className={CHAMP}>
                <option value="">{filtres.length === 0 ? 'Aucun client trouvé' : `Choisir un client (${filtres.length})`}</option>
                {filtres.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.enseigne}
                    {c.ville ? ` — ${c.ville}` : ''}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <fieldset className="flex flex-wrap items-center gap-1.5">
            <legend className="sr-only">Jours de visite</legend>
            {JOURS_COURTS.map((jour, idx) => {
              const n = idx + 1;
              const coche = jours.includes(n);
              return (
                <label
                  key={jour}
                  className={`cursor-pointer select-none rounded-md border px-2 py-1 text-xs transition has-focus-visible:outline has-focus-visible:outline-2 has-focus-visible:outline-brand dark:has-focus-visible:outline-accent ${
                    coche
                      ? 'border-brand bg-brand font-semibold text-white dark:border-accent dark:bg-accent dark:text-brand'
                      : 'border-neutral-200 text-neutral-600 dark:border-navy-700 dark:text-neutral-300'
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={coche}
                    onChange={() => setJours((j) => (j.includes(n) ? j.filter((x) => x !== n) : [...j, n]))}
                    className="sr-only"
                  />
                  {jour}
                </label>
              );
            })}
            <label htmlFor={idFreq} className="sr-only">Fréquence</label>
            <select id={idFreq} value={frequence} onChange={(e) => setFrequence(Number(e.target.value))} className={`ml-1 py-1 text-xs ${CHAMP}`}>
              {FREQUENCES.map((f) => (
                <option key={f.value} value={f.value}>
                  {f.label}
                </option>
              ))}
            </select>
          </fieldset>

          <div>
            <button
              type="button"
              onClick={creer}
              disabled={enCours || !clientId}
              className={`rounded-lg bg-brand px-3 py-2 text-sm font-medium text-white transition hover:opacity-90 disabled:opacity-50 ${FOCUS}`}
            >
              {enCours ? 'Création…' : 'Créer la récurrence'}
            </button>
          </div>
        </div>
      ) : null}

      {erreur ? (
        <p role="alert" className="mx-4 mt-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {erreur}
        </p>
      ) : null}

      {regles.length === 0 && !ouvert ? (
        <p className="px-4 py-3 text-xs text-neutral-500">
          Aucun client récurrent : les règles créées ici génèrent automatiquement les visites des semaines à venir.
        </p>
      ) : regles.length > 0 ? (
        <ul className={`flex flex-wrap gap-2 px-4 py-3 ${enCours ? 'opacity-60' : ''}`}>
          {regles.map((r) => (
            <li key={r.id} className="flex items-center gap-1.5 rounded-full bg-neutral-100 py-1 pl-2 pr-1 dark:bg-navy-800">
              <ClassBadge value={r.client.niveauClass} size="xs" />
              <span className="max-w-44 truncate text-xs font-medium">{r.client.enseigne}</span>
              <span className="text-[11px] text-brand dark:text-accent">
                {libelleJours(r.jours)} · {libelleFrequence(r.recurrence)}
              </span>
              <button
                type="button"
                disabled={enCours}
                onClick={() => retirer(r.id)}
                className={`rounded-full p-1 text-neutral-500 transition hover:bg-red-50 hover:text-red-600 ${FOCUS}`}
                aria-label={`Supprimer la récurrence ${r.client.enseigne}`}
                title="Supprimer (retire aussi les visites futures non faites)"
              >
                <Trash2 size={12} aria-hidden />
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
}
