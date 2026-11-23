'use client';

import { useEffect, useId, useMemo, useRef, useState, useTransition } from 'react';
import { ArrowDown, ArrowUp, Plus, Search, Trash2 } from 'lucide-react';
import {
  ajouterProduitIndispensable,
  rechercherArticles,
  reordonnerProduitsIndispensables,
  retirerProduitIndispensable,
} from '@/lib/produits-indispensables-actions';
import {
  RECHERCHE_MAX,
  articlesPresents,
  changementsApresDeplacement,
  cheminCentrale,
  enseignesVisibles,
  grouperParCentrale,
  pluriel,
  prochainOrdre,
  texteRecherche,
  type ArticleTrouve,
  type CentraleAdmin,
  type ProduitIndispensable,
} from '@/lib/produits-indispensables';

const FOCUS = 'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/40';
const CHAMP = `rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand ${FOCUS}`;
const BOUTON_ICONE = `rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-brand disabled:opacity-30 ${FOCUS}`;
const BOUTON_PRIMAIRE = `inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-1.5 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 ${FOCUS}`;
const DELAI_RECHERCHE_MS = 300;

function Erreur({ message }: { message: string | null }) {
  return message ? (
    <p role="alert" className="w-full text-xs text-red-600">
      {message}
    </p>
  ) : null;
}

function Pastille({ children }: { children: React.ReactNode }) {
  return <span className="rounded-full bg-neutral-100 px-1.5 py-0.5 text-[10px] font-semibold text-neutral-500">{children}</span>;
}

/** Recherche d'un article (code, libellé, code-barres, marque) et ajout à la liste de l'enseigne. */
function AjoutProduit({ centraleId, liste }: { centraleId: string; liste: ProduitIndispensable[] }) {
  const idChamp = useId();
  const [texte, setTexte] = useState('');
  const [resultats, setResultats] = useState<ArticleTrouve[] | null>(null);
  const [erreurRecherche, setErreurRecherche] = useState<string | null>(null);
  const [recherche, setRecherche] = useState(false);
  const [erreurAjout, setErreurAjout] = useState<string | null>(null);
  const [enCours, demarrer] = useTransition();
  const derniere = useRef(0);
  const presents = useMemo(() => articlesPresents(liste), [liste]);
  const ordre = useMemo(() => prochainOrdre(liste), [liste]);

  useEffect(() => {
    const q = texteRecherche(texte);
    const numero = ++derniere.current;
    if (!q) {
      setResultats(null);
      setErreurRecherche(null);
      setRecherche(false);
      return;
    }
    setRecherche(true);
    const minuteur = setTimeout(async () => {
      const reponse = await rechercherArticles(q);
      if (numero !== derniere.current) return;
      setRecherche(false);
      if (reponse.erreur !== undefined) {
        setErreurRecherche(reponse.erreur);
        setResultats(null);
      } else {
        setErreurRecherche(null);
        setResultats(reponse.data);
      }
    }, DELAI_RECHERCHE_MS);
    return () => clearTimeout(minuteur);
  }, [texte]);

  const ajouter = (article: ArticleTrouve) => {
    const fd = new FormData();
    fd.set('centraleId', centraleId);
    fd.set('articleId', article.id);
    fd.set('ordre', String(ordre));
    demarrer(async () => {
      const message = await ajouterProduitIndispensable(fd);
      setErreurAjout(message);
    });
  };

  return (
    <div className="flex flex-col gap-2">
      <label htmlFor={idChamp} className="text-sm font-medium">
        Ajouter un produit
      </label>
      <div className="relative">
        <Search size={14} className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-neutral-400" aria-hidden />
        <input
          id={idChamp}
          type="search"
          value={texte}
          onChange={(e) => setTexte(e.target.value)}
          maxLength={RECHERCHE_MAX}
          placeholder="Code, libellé, code-barres ou marque"
          autoComplete="off"
          className={`${CHAMP} w-full pl-8`}
        />
      </div>
      <Erreur message={erreurRecherche ?? erreurAjout} />
      <div aria-live="polite">
        {recherche ? <p className="text-xs text-neutral-400">Recherche…</p> : null}
        {!recherche && resultats && resultats.length === 0 ? (
          <p className="text-xs text-neutral-500">Aucun article trouvé.</p>
        ) : null}
      </div>
      {resultats && resultats.length > 0 ? (
        <ul className="divide-y divide-neutral-100 rounded-xl border border-neutral-200">
          {resultats.map((a) => {
            const dejaLa = presents.has(a.id);
            return (
              <li key={a.id} className="flex flex-wrap items-center gap-3 px-3 py-2">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">{a.libelle}</p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-500">
                    <span>{a.codeAs400}</span>
                    {a.marque ? <span>{a.marque.nom}</span> : null}
                    {!a.actif ? <Pastille>inactif</Pastille> : null}
                  </p>
                </div>
                {dejaLa ? (
                  <span className="text-xs text-neutral-500">Déjà dans la liste</span>
                ) : (
                  <button
                    type="button"
                    disabled={enCours}
                    onClick={() => ajouter(a)}
                    className={BOUTON_PRIMAIRE}
                    aria-label={`Ajouter « ${a.libelle} » à la liste`}
                  >
                    <Plus size={14} aria-hidden />
                    Ajouter
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
}

/** Liste des produits d'une enseigne : monter, descendre, retirer (avec confirmation). */
function ListeProduits({ liste }: { liste: ProduitIndispensable[] }) {
  const [enCours, demarrer] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  const lancer = (fd: FormData, action: (fd: FormData) => Promise<string | null>) => {
    demarrer(async () => setErreur(await action(fd)));
  };

  const deplacer = (index: number, direction: 'haut' | 'bas') => {
    const changements = changementsApresDeplacement(liste, index, direction);
    if (changements.length === 0) return;
    const fd = new FormData();
    fd.set('changements', JSON.stringify(changements));
    lancer(fd, reordonnerProduitsIndispensables);
  };

  const retirer = (ligne: ProduitIndispensable) => {
    if (!window.confirm(`Retirer « ${ligne.article.libelle} » de la liste ?`)) return;
    const fd = new FormData();
    fd.set('id', ligne.id);
    lancer(fd, retirerProduitIndispensable);
  };

  if (liste.length === 0) {
    return <p className="rounded-xl bg-neutral-50 px-5 py-6 text-center text-sm text-neutral-400">Aucun produit indispensable.</p>;
  }

  return (
    <div className="flex flex-col gap-2">
      <Erreur message={erreur} />
      <ul className="divide-y divide-neutral-100 rounded-xl border border-neutral-200">
        {liste.map((ligne, i) => (
          <li key={ligne.id} className="flex flex-wrap items-center gap-3 px-3 py-2">
            <div className="flex flex-col">
              <button
                type="button"
                disabled={enCours || i === 0}
                onClick={() => deplacer(i, 'haut')}
                className={BOUTON_ICONE}
                aria-label={`Monter « ${ligne.article.libelle} »`}
              >
                <ArrowUp size={14} aria-hidden />
              </button>
              <button
                type="button"
                disabled={enCours || i === liste.length - 1}
                onClick={() => deplacer(i, 'bas')}
                className={BOUTON_ICONE}
                aria-label={`Descendre « ${ligne.article.libelle} »`}
              >
                <ArrowDown size={14} aria-hidden />
              </button>
            </div>
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-semibold text-neutral-500">
              {i + 1}
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium">{ligne.article.libelle}</p>
              <p className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-neutral-500">
                <span>{ligne.article.codeAs400}</span>
                {ligne.article.marque ? <span>{ligne.article.marque.nom}</span> : null}
              </p>
            </div>
            <button
              type="button"
              disabled={enCours}
              onClick={() => retirer(ligne)}
              className={`rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-30 ${FOCUS}`}
              aria-label={`Retirer « ${ligne.article.libelle} »`}
              title="Retirer"
            >
              <Trash2 size={14} aria-hidden />
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function ProduitsIndispensablesEditeur({
  centrales,
  lignes,
}: {
  centrales: CentraleAdmin[];
  lignes: ProduitIndispensable[];
}) {
  const idFiltre = useId();
  const [filtre, setFiltre] = useState('');
  const [toutes, setToutes] = useState(false);
  const [choix, setChoix] = useState<string | null>(null);

  const groupes = useMemo(() => grouperParCentrale(lignes), [lignes]);
  const comptes = useMemo(() => new Map([...groupes].map(([id, liste]) => [id, liste.length])), [groupes]);
  const parId = useMemo(() => new Map(centrales.map((c) => [c.id, c])), [centrales]);
  const { visibles, masquees } = useMemo(
    () => enseignesVisibles(centrales, comptes, filtre, toutes),
    [centrales, comptes, filtre, toutes],
  );

  const selection = choix ? (parId.get(choix) ?? null) : null;
  const liste = selection ? (groupes.get(selection.id) ?? []) : [];

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,20rem)_minmax(0,1fr)]">
      <div className="flex flex-col gap-3 rounded-2xl bg-white p-4 shadow-card">
        <label htmlFor={idFiltre} className="text-sm font-medium">
          Enseigne
        </label>
        <input
          id={idFiltre}
          type="search"
          value={filtre}
          onChange={(e) => setFiltre(e.target.value)}
          placeholder="Filtrer par nom ou code"
          autoComplete="off"
          className={CHAMP}
        />
        {visibles.length === 0 ? (
          <p className="py-4 text-center text-sm text-neutral-400">Aucune enseigne.</p>
        ) : (
          <ul className="flex max-h-96 flex-col gap-1 overflow-y-auto">
            {visibles.map((c) => {
              const courante = c.id === selection?.id;
              const nb = comptes.get(c.id) ?? 0;
              return (
                <li key={c.id}>
                  <button
                    type="button"
                    onClick={() => setChoix(c.id)}
                    aria-pressed={courante}
                    className={`flex w-full items-start gap-2 rounded-lg px-3 py-2 text-left text-sm transition ${FOCUS} ${
                      courante ? 'bg-brand/10 text-navy' : 'text-neutral-700 hover:bg-neutral-50'
                    }`}
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium">{c.nom}</span>
                      <span className="block truncate text-xs text-neutral-500">
                        {c.code}
                        {c.nbClients > 0 ? ` · ${pluriel(c.nbClients, 'magasin')}` : ''}
                      </span>
                    </span>
                    <span
                      className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold ${
                        nb > 0 ? 'bg-brand/10 text-brand' : 'bg-neutral-100 text-neutral-400'
                      }`}
                      aria-label={pluriel(nb, 'produit indispensable', 'produits indispensables')}
                    >
                      {nb}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
        {masquees > 0 || toutes ? (
          <button
            type="button"
            onClick={() => setToutes((v) => !v)}
            className={`self-start rounded-lg px-1 text-xs font-medium text-brand underline-offset-2 hover:underline ${FOCUS}`}
          >
            {toutes ? 'Masquer les enseignes sans magasin' : `Afficher ${pluriel(masquees, 'enseigne')} sans magasin`}
          </button>
        ) : null}
      </div>

      <div className="min-w-0 rounded-2xl bg-white p-4 shadow-card">
        {selection ? (
          <div key={selection.id} className="flex flex-col gap-4">
            <div>
              <h3 className="text-base font-semibold">{selection.nom}</h3>
              <p className="text-xs text-neutral-500">
                {cheminCentrale(selection, parId)} · {selection.code} · {pluriel(liste.length, 'produit indispensable', 'produits indispensables')}
              </p>
            </div>
            <AjoutProduit centraleId={selection.id} liste={liste} />
            <ListeProduits liste={liste} />
          </div>
        ) : (
          <p className="px-5 py-10 text-center text-sm text-neutral-400">Sélectionnez une enseigne.</p>
        )}
      </div>
    </div>
  );
}
