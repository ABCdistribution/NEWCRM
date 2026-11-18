'use client';

import { useRef, useState, useTransition, type FormEvent, type ReactNode } from 'react';
import { ArrowDown, ArrowUp, Pencil, Plus, Power, Trash2, X } from 'lucide-react';
import {
  ajouterQuestion,
  ajouterRaison,
  deplacerQuestion,
  deplacerRaison,
  modifierQuestion,
  modifierRaison,
  supprimerQuestion,
  supprimerRaison,
} from '@/lib/visites-admin-actions';
import {
  LIBELLES_TYPE,
  LONGUEUR_QUESTION,
  LONGUEUR_RAISON,
  TYPES_QUESTION,
  type QuestionVisite,
  type RaisonAbsenceCommande,
  type TypeQuestion,
} from '@/lib/visites-admin';

type Action = (formData: FormData) => Promise<string | null>;

const FOCUS = 'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/40';
const CHAMP = `rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand ${FOCUS}`;
const BOUTON_PRIMAIRE = `inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 ${FOCUS}`;
const BOUTON_ICONE = `rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-brand disabled:opacity-30 ${FOCUS}`;

/** Exécute une Server Action en transition et garde son message d'erreur (null = succès). */
function useAppel() {
  const [enCours, demarrer] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);
  const lancer = (action: Action, formData: FormData, apres?: () => void) => {
    demarrer(async () => {
      const message = await action(formData);
      setErreur(message);
      if (!message) apres?.();
    });
  };
  return { enCours, erreur, lancer };
}

function Erreur({ message }: { message: string | null }) {
  return message ? (
    <p role="alert" className="w-full text-xs text-red-600">
      {message}
    </p>
  ) : null;
}

function donnees(valeurs: Record<string, string>): FormData {
  const fd = new FormData();
  for (const [cle, valeur] of Object.entries(valeurs)) fd.set(cle, valeur);
  return fd;
}

type ActionsLigne = { deplacer: Action; modifier: Action; supprimer: Action };

/** Ligne d'une liste ordonnée : monter / descendre, activer, modifier, supprimer. */
function Ligne({
  id,
  libelle,
  index,
  total,
  actif,
  actions,
  contenu,
  edition,
}: {
  id: string;
  libelle: string;
  index: number;
  total: number;
  actif: boolean;
  actions: ActionsLigne;
  contenu: ReactNode;
  edition: (fermer: () => void) => ReactNode;
}) {
  const [modification, setModification] = useState(false);
  const { enCours, erreur, lancer } = useAppel();

  if (modification) return <li>{edition(() => setModification(false))}</li>;

  return (
    <li className={`flex flex-wrap items-center gap-3 px-4 py-3 ${actif ? '' : 'bg-neutral-50'}`}>
      <div className="flex flex-col">
        <button
          type="button"
          disabled={enCours || index === 0}
          onClick={() => lancer(actions.deplacer, donnees({ id, direction: 'haut' }))}
          className={BOUTON_ICONE}
          aria-label={`Monter « ${libelle} »`}
        >
          <ArrowUp size={14} aria-hidden />
        </button>
        <button
          type="button"
          disabled={enCours || index === total - 1}
          onClick={() => lancer(actions.deplacer, donnees({ id, direction: 'bas' }))}
          className={BOUTON_ICONE}
          aria-label={`Descendre « ${libelle} »`}
        >
          <ArrowDown size={14} aria-hidden />
        </button>
      </div>
      <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-semibold text-neutral-500">
        {index + 1}
      </span>
      <div className={`min-w-0 flex-1 ${actif ? '' : 'opacity-60'}`}>{contenu}</div>
      <div className="flex shrink-0 items-center gap-1">
        <button
          type="button"
          disabled={enCours}
          onClick={() => lancer(actions.modifier, donnees({ id, actif: String(!actif) }))}
          className={BOUTON_ICONE}
          aria-label={actif ? `Désactiver « ${libelle} »` : `Activer « ${libelle} »`}
          title={actif ? 'Désactiver' : 'Activer'}
        >
          <Power size={14} aria-hidden />
        </button>
        <button
          type="button"
          disabled={enCours}
          onClick={() => setModification(true)}
          className={BOUTON_ICONE}
          aria-label={`Modifier « ${libelle} »`}
          title="Modifier"
        >
          <Pencil size={14} aria-hidden />
        </button>
        <button
          type="button"
          disabled={enCours}
          onClick={() => {
            if (window.confirm(`Supprimer « ${libelle} » ?`)) lancer(actions.supprimer, donnees({ id }));
          }}
          className={`rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-30 ${FOCUS}`}
          aria-label={`Supprimer « ${libelle} »`}
          title="Supprimer"
        >
          <Trash2 size={14} aria-hidden />
        </button>
      </div>
      <Erreur message={erreur} />
    </li>
  );
}

function Pastille({ children }: { children: ReactNode }) {
  return <span className="rounded-full bg-neutral-100 px-1.5 py-0.5 text-[10px] font-semibold text-neutral-500">{children}</span>;
}

// --- Questionnaire de fin de visite -----------------------------------------------------------

const ACTIONS_QUESTION: ActionsLigne = { deplacer: deplacerQuestion, modifier: modifierQuestion, supprimer: supprimerQuestion };

function SelectType({ nom, defaut, libelle }: { nom: string; defaut: TypeQuestion; libelle: string }) {
  return (
    <select name={nom} defaultValue={defaut} aria-label={libelle} className={CHAMP}>
      {TYPES_QUESTION.map((t) => (
        <option key={t} value={t}>
          {LIBELLES_TYPE[t]}
        </option>
      ))}
    </select>
  );
}

function AjoutQuestion() {
  const { enCours, erreur, lancer } = useAppel();
  const formulaire = useRef<HTMLFormElement>(null);

  const soumettre = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    lancer(ajouterQuestion, new FormData(e.currentTarget), () => formulaire.current?.reset());
  };

  return (
    <form ref={formulaire} onSubmit={soumettre} className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card">
      <input
        name="libelle"
        required
        maxLength={LONGUEUR_QUESTION}
        placeholder="Nouvelle question"
        aria-label="Libellé de la nouvelle question"
        className={`${CHAMP} min-w-60 flex-1`}
      />
      <SelectType nom="type" defaut="CASE_A_COCHER" libelle="Type de la nouvelle question" />
      <label className="inline-flex items-center gap-1.5 text-sm text-neutral-600">
        <input type="checkbox" name="obligatoire" className="accent-brand" />
        Obligatoire
      </label>
      <button type="submit" disabled={enCours} className={BOUTON_PRIMAIRE}>
        <Plus size={14} aria-hidden />
        {enCours ? 'Ajout…' : 'Ajouter'}
      </button>
      <Erreur message={erreur} />
    </form>
  );
}

function EditionQuestion({ question, fermer }: { question: QuestionVisite; fermer: () => void }) {
  const { enCours, erreur, lancer } = useAppel();
  const [obligatoire, setObligatoire] = useState(question.obligatoire);

  const soumettre = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    fd.set('obligatoire', String(obligatoire));
    lancer(modifierQuestion, fd, fermer);
  };

  return (
    <form onSubmit={soumettre} className="flex flex-wrap items-center gap-2 px-4 py-3">
      <input type="hidden" name="id" value={question.id} />
      <input
        name="libelle"
        defaultValue={question.libelle}
        required
        maxLength={LONGUEUR_QUESTION}
        aria-label="Libellé de la question"
        className={`${CHAMP} min-w-60 flex-1`}
      />
      <SelectType nom="type" defaut={question.type} libelle="Type de la question" />
      <label className="inline-flex items-center gap-1.5 text-sm text-neutral-600">
        <input type="checkbox" checked={obligatoire} onChange={(e) => setObligatoire(e.target.checked)} className="accent-brand" />
        Obligatoire
      </label>
      <button type="submit" disabled={enCours} className={BOUTON_PRIMAIRE}>
        {enCours ? 'Enregistrement…' : 'Enregistrer'}
      </button>
      <button type="button" onClick={fermer} className={BOUTON_ICONE} aria-label="Annuler la modification">
        <X size={14} aria-hidden />
      </button>
      <Erreur message={erreur} />
    </form>
  );
}

export function QuestionnaireEditeur({ questions }: { questions: QuestionVisite[] }) {
  return (
    <div className="flex flex-col gap-3">
      <AjoutQuestion />
      <div className="rounded-2xl bg-white shadow-card">
        {questions.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-neutral-400">Aucune question.</p>
        ) : (
          <ul className="divide-y divide-neutral-100">
            {questions.map((q, i) => (
              <Ligne
                key={q.id}
                id={q.id}
                libelle={q.libelle}
                index={i}
                total={questions.length}
                actif={q.actif}
                actions={ACTIONS_QUESTION}
                contenu={
                  <>
                    <p className="text-sm font-medium">{q.libelle}</p>
                    <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-500">
                      <span>{LIBELLES_TYPE[q.type] ?? q.type}</span>
                      {q.obligatoire ? <Pastille>obligatoire</Pastille> : null}
                      {!q.actif ? <Pastille>désactivée</Pastille> : null}
                      {q._count.reponses > 0 ? (
                        <span>
                          {q._count.reponses} réponse{q._count.reponses > 1 ? 's' : ''}
                        </span>
                      ) : null}
                    </p>
                  </>
                }
                edition={(fermer) => <EditionQuestion question={q} fermer={fermer} />}
              />
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

// --- Raisons d'absence de commande ------------------------------------------------------------

const ACTIONS_RAISON: ActionsLigne = { deplacer: deplacerRaison, modifier: modifierRaison, supprimer: supprimerRaison };

function AjoutRaison() {
  const { enCours, erreur, lancer } = useAppel();
  const formulaire = useRef<HTMLFormElement>(null);

  const soumettre = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    lancer(ajouterRaison, new FormData(e.currentTarget), () => formulaire.current?.reset());
  };

  return (
    <form ref={formulaire} onSubmit={soumettre} className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card">
      <input
        name="libelle"
        required
        maxLength={LONGUEUR_RAISON}
        placeholder="Nouvelle raison"
        aria-label="Libellé de la nouvelle raison"
        className={`${CHAMP} min-w-60 flex-1`}
      />
      <button type="submit" disabled={enCours} className={BOUTON_PRIMAIRE}>
        <Plus size={14} aria-hidden />
        {enCours ? 'Ajout…' : 'Ajouter'}
      </button>
      <Erreur message={erreur} />
    </form>
  );
}

function EditionRaison({ raison, fermer }: { raison: RaisonAbsenceCommande; fermer: () => void }) {
  const { enCours, erreur, lancer } = useAppel();

  const soumettre = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    lancer(modifierRaison, new FormData(e.currentTarget), fermer);
  };

  return (
    <form onSubmit={soumettre} className="flex flex-wrap items-center gap-2 px-4 py-3">
      <input type="hidden" name="id" value={raison.id} />
      <input
        name="libelle"
        defaultValue={raison.libelle}
        required
        maxLength={LONGUEUR_RAISON}
        aria-label="Libellé de la raison"
        className={`${CHAMP} min-w-60 flex-1`}
      />
      <button type="submit" disabled={enCours} className={BOUTON_PRIMAIRE}>
        {enCours ? 'Enregistrement…' : 'Enregistrer'}
      </button>
      <button type="button" onClick={fermer} className={BOUTON_ICONE} aria-label="Annuler la modification">
        <X size={14} aria-hidden />
      </button>
      <Erreur message={erreur} />
    </form>
  );
}

export function RaisonsEditeur({ raisons }: { raisons: RaisonAbsenceCommande[] }) {
  return (
    <div className="flex flex-col gap-3">
      <AjoutRaison />
      <div className="rounded-2xl bg-white shadow-card">
        {raisons.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-neutral-400">Aucune raison.</p>
        ) : (
          <ul className="divide-y divide-neutral-100">
            {raisons.map((r, i) => (
              <Ligne
                key={r.id}
                id={r.id}
                libelle={r.libelle}
                index={i}
                total={raisons.length}
                actif={r.actif}
                actions={ACTIONS_RAISON}
                contenu={
                  <>
                    <p className="text-sm font-medium">{r.libelle}</p>
                    <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-500">
                      {!r.actif ? <Pastille>désactivée</Pastille> : null}
                      {r._count.visites > 0 ? (
                        <span>
                          {r._count.visites} visite{r._count.visites > 1 ? 's' : ''}
                        </span>
                      ) : null}
                    </p>
                  </>
                }
                edition={(fermer) => <EditionRaison raison={r} fermer={fermer} />}
              />
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
