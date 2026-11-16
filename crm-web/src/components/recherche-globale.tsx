'use client';

import { useEffect, useId, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowRight, Footprints, Loader2, Package, Search, ShoppingCart, Sprout, Store, UsersRound, type LucideIcon } from 'lucide-react';
import type { Role } from '@/lib/api';
import { rechercherGlobal } from '@/lib/recherche-actions';
import {
  FAMILLES,
  lienResultat,
  lienTous,
  type RechercheGlobale as Donnees,
  type Resultat,
  type TypeResultat,
} from '@/lib/recherche';

const ICONES: Record<TypeResultat, LucideIcon> = {
  clients: Store,
  commandes: ShoppingCart,
  visites: Footprints,
  collaborateurs: UsersRound,
  prospects: Sprout,
  produits: Package,
};

/** Attente après la dernière frappe avant d'interroger l'API. */
const DELAI_MS = 250;
const MIN = 2;

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

type Ligne = { cle: string; r: Resultat; href: string | null; index: number };
type Famille = { type: TypeResultat; libelle: string; total: number; lignes: Ligne[]; tous: { href: string; index: number } | null };

/**
 * Recherche générale du bandeau : clients, commandes, visites, collaborateurs, prospects et produits en une saisie.
 * Les résultats viennent de `rechercherGlobal` (Server Action → `GET /search`), déjà bornés par rôle et périmètre :
 * rien n'est filtré ici. Un résultat sans page où l'envoyer pour ce rôle reste affiché, sans lien.
 * Clavier : flèches haut / bas, Entrée (ouvre la ligne choisie, sinon la première), Échap (ferme, puis efface).
 * `resultatInitial` / `saisieInitiale` : états d'ouverture pour les tests de rendu.
 */
export function RechercheGlobale({
  role,
  resultatInitial = null,
  saisieInitiale = '',
}: {
  role: Role;
  resultatInitial?: Donnees | null;
  saisieInitiale?: string;
}) {
  const router = useRouter();
  const base = useId();
  const champ = useRef<HTMLInputElement>(null);
  const sequence = useRef(0);

  const [saisie, setSaisie] = useState(saisieInitiale);
  const [donnees, setDonnees] = useState<Donnees | null>(resultatInitial);
  const [erreur, setErreur] = useState<string | null>(null);
  const [attente, setAttente] = useState(false);
  const [ouvert, setOuvert] = useState(resultatInitial !== null);
  const [actif, setActif] = useState(-1);

  const q = saisie.trim().replace(/\s+/g, ' ');
  const assezLong = q.length >= MIN;

  // Interroge l'API 250 ms après la dernière frappe ; une réponse arrivée après une saisie plus récente est ignorée.
  useEffect(() => {
    if (!assezLong) {
      sequence.current += 1;
      setDonnees(null);
      setErreur(null);
      setAttente(false);
      return;
    }
    setAttente(true);
    const n = ++sequence.current;
    const minuteur = setTimeout(async () => {
      const r = await rechercherGlobal(q);
      if (n !== sequence.current) return;
      setAttente(false);
      setActif(-1);
      if (r.erreur !== undefined) {
        setErreur(r.erreur);
        setDonnees(null);
      } else {
        setErreur(null);
        setDonnees(r.data);
      }
    }, DELAI_MS);
    return () => clearTimeout(minuteur);
  }, [q, assezLong]);

  // Familles à afficher, avec l'index de chaque ligne dans la liste navigable au clavier (lignes avec lien seulement).
  const { familles, liens } = useMemo(() => {
    const liens: string[] = [];
    const familles: Famille[] = [];
    for (const f of FAMILLES) {
      const g = donnees?.groupes.find((x) => x.type === f.type);
      if (!g) continue;
      const lignes: Ligne[] = g.items.map((r) => {
        const href = lienResultat(f.type, r, role);
        let index = -1;
        if (href) {
          index = liens.length;
          liens.push(href);
        }
        return { cle: r.id, r, href, index };
      });
      let tous: Famille['tous'] = null;
      const hrefTous = g.total > g.items.length ? lienTous(f.type, donnees?.q ?? q) : null;
      if (hrefTous) {
        tous = { href: hrefTous, index: liens.length };
        liens.push(hrefTous);
      }
      familles.push({ type: f.type, libelle: f.libelle, total: g.total, lignes, tous });
    }
    return { familles, liens };
  }, [donnees, role, q]);

  const idOption = (i: number) => `${base}-option-${i}`;
  const panneauVisible = ouvert && assezLong && (attente || erreur !== null || donnees !== null);

  const fermer = (effacer = false) => {
    setOuvert(false);
    setActif(-1);
    if (effacer) setSaisie('');
  };
  const ouvrir = (href: string) => {
    fermer(true);
    champ.current?.blur();
    router.push(href);
  };

  const surClavier = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (liens.length === 0) return;
      e.preventDefault();
      setOuvert(true);
      setActif((i) => (e.key === 'ArrowDown' ? Math.min(i + 1, liens.length - 1) : Math.max(i - 1, -1)));
    } else if (e.key === 'Enter') {
      // Pas d'Entrée pendant une recherche en cours (elle ouvrirait un résultat de la saisie précédente) ni pendant
      // la composition d'un texte (IME).
      if (attente || e.nativeEvent.isComposing) return;
      const cible = liens[actif >= 0 ? actif : 0];
      if (panneauVisible && cible) {
        e.preventDefault();
        ouvrir(cible);
      }
    } else if (e.key === 'Escape') {
      if (ouvert && assezLong) fermer();
      else setSaisie('');
    }
  };

  return (
    <div
      className="relative w-full"
      // Le panneau se ferme quand le focus sort de la zone (clic ailleurs, Tab).
      onBlur={(e) => {
        if (!e.currentTarget.contains(e.relatedTarget as Node | null)) fermer();
      }}
    >
      <label htmlFor={`${base}-champ`} className="sr-only">
        Recherche générale
      </label>
      <input
        ref={champ}
        id={`${base}-champ`}
        type="text"
        role="combobox"
        aria-expanded={panneauVisible}
        aria-controls={`${base}-liste`}
        aria-autocomplete="list"
        aria-activedescendant={panneauVisible && actif >= 0 ? idOption(actif) : undefined}
        autoComplete="off"
        spellCheck={false}
        maxLength={80}
        value={saisie}
        onChange={(e) => {
          setSaisie(e.target.value);
          setOuvert(true);
        }}
        onFocus={() => setOuvert(true)}
        onClick={() => setOuvert(true)}
        onKeyDown={surClavier}
        placeholder="Rechercher un client, une commande, une visite, un collaborateur…"
        className={`h-11 w-full rounded-xl border border-transparent bg-neutral-100 pl-4 pr-11 text-sm placeholder:text-neutral-500 transition focus:border-brand focus:bg-white focus:outline-none dark:bg-navy-800 ${FOCUS}`}
      />
      <span className="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-neutral-500" aria-hidden>
        {attente ? <Loader2 size={18} className="animate-spin motion-reduce:animate-none" /> : <Search size={18} />}
      </span>

      {panneauVisible ? (
        <div
          id={`${base}-liste`}
          role="listbox"
          aria-label="Résultats de la recherche"
          aria-busy={attente}
          // Un clic sur une zone non cliquable du panneau (barre de défilement, titre) ne doit pas faire perdre le focus.
          onMouseDown={(e) => e.preventDefault()}
          className="absolute left-0 right-0 top-full z-40 mt-2 max-h-[70vh] overflow-y-auto rounded-2xl border border-neutral-200 bg-white p-2 shadow-lg"
        >
          {erreur !== null ? (
            <p role="alert" className="px-3 py-3 text-sm text-red-700">
              {erreur}
            </p>
          ) : donnees === null ? (
            <p role="status" className="px-3 py-3 text-sm text-neutral-500">
              Recherche en cours…
            </p>
          ) : familles.length === 0 ? (
            <p role="status" className="px-3 py-3 text-sm text-neutral-500">
              Aucun résultat pour « {donnees.q} ».
            </p>
          ) : (
            familles.map((f) => {
              const Icone = ICONES[f.type];
              return (
                <div key={f.type} role="group" aria-label={f.libelle} className="mt-1 first:mt-0">
                  <p className="px-3 pb-1 pt-2 text-xs font-semibold uppercase tracking-wide text-neutral-500">{f.libelle}</p>
                  {f.lignes.map((l) => {
                    const contenu = (
                      <>
                        <Icone size={16} className="shrink-0 text-neutral-500" aria-hidden />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate font-medium">{l.r.titre}</span>
                          {l.r.detail ? <span className="block truncate text-xs text-neutral-500">{l.r.detail}</span> : null}
                        </span>
                      </>
                    );
                    const classes = 'flex items-center gap-3 rounded-xl px-3 py-2 text-sm';
                    return l.href ? (
                      <Link
                        key={l.cle}
                        id={idOption(l.index)}
                        role="option"
                        aria-selected={actif === l.index}
                        href={l.href}
                        onClick={() => fermer(true)}
                        className={`${classes} ${FOCUS} ${actif === l.index ? 'bg-brand/10' : 'hover:bg-neutral-100'}`}
                      >
                        {contenu}
                      </Link>
                    ) : (
                      <div key={l.cle} role="option" aria-disabled aria-selected={false} className={`${classes} text-neutral-700`}>
                        {contenu}
                      </div>
                    );
                  })}
                  {f.tous ? (
                    <Link
                      id={idOption(f.tous.index)}
                      role="option"
                      aria-selected={actif === f.tous.index}
                      href={f.tous.href}
                      onClick={() => fermer(true)}
                      className={`flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-medium text-brand ${FOCUS} ${
                        actif === f.tous.index ? 'bg-brand/10' : 'hover:bg-neutral-100'
                      }`}
                    >
                      Voir les {f.total} résultats
                      <ArrowRight size={13} aria-hidden />
                    </Link>
                  ) : null}
                </div>
              );
            })
          )}
        </div>
      ) : null}
    </div>
  );
}
