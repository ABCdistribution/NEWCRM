'use client';

import { useEffect, useState } from 'react';
import { BadgeCheck, Save } from 'lucide-react';

type Etat = { prevision?: string; validation?: string }; // ISO des enregistrements

const cle = (semaine: string) => `planning-validation:${semaine}`;

const FMT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

/**
 * Prévision & validation du planning de la semaine — flux « virtuel » pour
 * l'instant : l'état est mémorisé côté navigateur (par semaine) en attendant
 * le circuit de validation serveur (rapport d'activité).
 */
export function PlanningValidation({ semaine, nbEtapes }: { semaine: string; nbEtapes: number }) {
  const [etat, setEtat] = useState<Etat>({});
  const [monte, setMonte] = useState(false);

  useEffect(() => {
    setMonte(true);
    try {
      setEtat(JSON.parse(localStorage.getItem(cle(semaine)) ?? '{}') as Etat);
    } catch {
      setEtat({});
    }
  }, [semaine]);

  const enregistrer = (champ: keyof Etat) => {
    const suivant = { ...etat, [champ]: new Date().toISOString() };
    setEtat(suivant);
    try {
      localStorage.setItem(cle(semaine), JSON.stringify(suivant));
    } catch {
      // stockage indisponible — l'état reste pour la session en cours
    }
  };

  if (!monte) return null;

  return (
    <div className="flex flex-wrap items-center gap-2">
      {etat.validation ? (
        <span className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-500/12 px-3 py-1.5 text-xs font-semibold text-emerald-600 dark:text-emerald-400">
          <BadgeCheck size={14} /> Planning validé le {FMT.format(new Date(etat.validation))}
        </span>
      ) : (
        <>
          {etat.prevision ? (
            <span className="inline-flex items-center gap-1.5 rounded-xl bg-sky-500/12 px-3 py-1.5 text-xs font-semibold text-sky-600 dark:text-sky-400">
              <Save size={13} /> Prévision du {FMT.format(new Date(etat.prevision))}
            </span>
          ) : (
            <button
              type="button"
              onClick={() => enregistrer('prevision')}
              disabled={nbEtapes === 0}
              title={nbEtapes === 0 ? 'Aucune étape planifiée cette semaine' : `Enregistrer la prévision (${nbEtapes} étapes)`}
              className="inline-flex items-center gap-1.5 rounded-xl border border-neutral-200 bg-white px-3 py-1.5 text-xs font-semibold text-neutral-600 shadow-sm transition hover:border-brand hover:text-brand disabled:opacity-40 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-300 dark:hover:border-accent dark:hover:text-accent"
            >
              <Save size={13} /> Sauvegarder la prévision
            </button>
          )}
          <button
            type="button"
            onClick={() => enregistrer('validation')}
            disabled={nbEtapes === 0}
            title={nbEtapes === 0 ? 'Aucune étape planifiée cette semaine' : 'Valider le planning de la semaine'}
            className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
          >
            <BadgeCheck size={14} /> Valider le planning
          </button>
        </>
      )}
    </div>
  );
}
