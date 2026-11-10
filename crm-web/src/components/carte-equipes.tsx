'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { AnimatePresence, MotionConfig, motion } from 'framer-motion';
import { ArrowLeft, ArrowRight, Search } from 'lucide-react';
import { libelleRole } from '@/lib/activite';
import { teinteRegion } from '@/lib/carte-palette';
import { FORMES_REGIONS_FDV, formeRegionFdv } from '@/lib/carte-regions-fdv';
import type { CarteEquipes, CarteRegion } from '@/lib/carte';
import { BilanRegion, CaObjectifADate, LigneActivite, LigneCa } from './activite-equipe';
import { Avatar } from './avatar';
import { CarteRegionsSvg } from './carte-regions-svg';
import { initiales } from './equipe-ui';

const normaliser = (s: string) =>
  s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');

const pluriel = (n: number, mot: string) => `${n} ${mot}${n > 1 ? 's' : ''}`;

/** Photo AD du collaborateur (proxy `/avatar/[id]`) ; ses initiales restent affichées tant qu'il n'y en a pas. */
const Photo = ({ id, nom, taille }: { id: string; nom: string; taille: number }) => (
  <Avatar src={`/avatar/${encodeURIComponent(id)}`} initials={initiales(nom)} size={taille} />
);

/**
 * Titre et sous-titre d'une région : « BENELUX Belgique » donne « BENELUX » et « Belgique ».
 * Seul un nom commençant par des MAJUSCULES suivies d'un mot capitalisé est scindé ; les autres noms
 * (« NORD OUEST », « Île-de-France », « Sud Est », « IDF ») restent entiers. À défaut, le sous-titre est celui de la
 * carte (« Belgique » sous « Benelux »).
 */
function scinderNom(r: CarteRegion): { titre: string; sousTitre: string | null } {
  const nom = r.nom.trim();
  const m = /^([A-ZÀ-ÖØ-Þ][A-ZÀ-ÖØ-Þ0-9'’ -]*?)\s+([A-ZÀ-ÖØ-Þ][a-zà-öø-ÿ].*)$/.exec(nom);
  if (m) return { titre: m[1], sousTitre: m[2] };
  return { titre: nom, sousTitre: formeRegionFdv(r.code)?.sousTitre ?? null };
}

/** Rang d'une région dans l'ordre de l'annuaire (celui des formes de la carte) ; les inconnues viennent après. */
const rangRegion = (code: string) => {
  const i = FORMES_REGIONS_FDV.findIndex((f) => f.code === code);
  return i === -1 ? FORMES_REGIONS_FDV.length : i;
};

const focus =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';

/**
 * Carte « Les équipes Force de Vente » (DR / ADMIN / DIRECTION) : régions colorées avec effectif,
 * phrase d'introduction (effectif total et nombre de secteurs), filtre par pastille, recherche par nom,
 * liste des secteurs sous la carte (nom, effectif, flèche) et détail chefs de secteur → promoteurs.
 * Les noms des chefs de secteur et des promoteurs renvoient vers leurs fiches (/mon-equipe/...) UNIQUEMENT
 * quand le rôle de l'utilisateur peut les ouvrir (`ficheChefSecteur`, `fichePromoteur`, calculés côté serveur
 * par `carte-fiches.ts`) : DIRECTION n'a accès à aucune de ces fiches, un lien le mènerait à « Accès
 * refusé ». Sans droit, le nom s'affiche en texte simple. Les pages de destination gardent leurs propres
 * règles d'accès : ces booléens n'évitent que les liens morts, ils ne protègent rien.
 */
export function CarteEquipes({
  data,
  ficheChefSecteur,
  fichePromoteur,
  regionInitiale = null,
  sansCarte = false,
}: {
  data: CarteEquipes;
  ficheChefSecteur: boolean;
  fichePromoteur: boolean;
  /** Région sélectionnée à l'ouverture (aucune par défaut) : sert aux tests et à ouvrir la carte sur une région. */
  regionInitiale?: string | null;
  /**
   * Sans carte de France ni liste des secteurs ni pastilles : les équipes de toutes les régions reçues sont affichées
   * directement, l'une sous l'autre. Pour le directeur régional, qui n'a qu'une ou deux régions.
   */
  sansCarte?: boolean;
}) {
  const [regionId, setRegionId] = useState<string | null>(regionInitiale);
  const [recherche, setRecherche] = useState('');

  // La carte se replie dès qu'une région est choisie : le focus passe alors sur « Retour à la carte » (le bouton
  // cliqué disparaît), et revient sur le titre quand on la rouvre. Rien au premier rendu. `preventScroll` : le focus
  // ne doit JAMAIS faire défiler la page (sinon elle remonte à chaque clic sur un filtre).
  const retourRef = useRef<HTMLButtonElement>(null);
  const titreRef = useRef<HTMLHeadingElement>(null);
  const premierRendu = useRef(true);
  useEffect(() => {
    if (premierRendu.current) {
      premierRendu.current = false;
      return;
    }
    (regionId ? retourRef.current : titreRef.current)?.focus({ preventScroll: true });
  }, [regionId === null]); // eslint-disable-line react-hooks/exhaustive-deps

  // Teinte de chaque région : celle de l'annuaire (par code de région), neutre pour une région sans tracé.
  // Ordre fixe, celui de l'annuaire (IDF, Nord-Ouest, Nord-Est, Sud-Est, Sud-Ouest, Benelux, Corse) pour les pastilles,
  // la liste et le détail ; une région que la carte ne connaît pas passe à la fin (par nom).
  const regions = useMemo(
    () =>
      data.regions
        .map((r) => ({ ...r, couleur: teinteRegion(r.code).point }))
        .sort((a, b) => rangRegion(a.code) - rangRegion(b.code) || a.nom.localeCompare(b.nom, 'fr')),
    [data.regions],
  );
  const total = regions.reduce((s, r) => s + r.nbCollaborateurs, 0);

  const basculer = (id: string) => setRegionId((cur) => (cur === id ? null : id));

  const q = normaliser(recherche.trim());
  const aRecherche = q.length > 0;

  // Détail : région sélectionnée, ou toutes les régions si une recherche est en cours.
  const detail = useMemo(() => {
    const sources = regionId ? regions.filter((r) => r.id === regionId) : aRecherche || sansCarte ? regions : [];
    return sources
      .map((r) => {
        const chefs = r.chefsSecteur
          .map((c) => {
            if (!aRecherche) return c;
            const chefOk = normaliser(c.displayName).includes(q);
            const promos = c.promoteurs.filter((p) => normaliser(p.displayName).includes(q));
            if (chefOk) return c;
            return promos.length > 0 ? { ...c, promoteurs: promos } : null;
          })
          .filter((c): c is NonNullable<typeof c> => c !== null);
        const directeurs = r.directeurs.filter((d) => !aRecherche || normaliser(d.displayName).includes(q));
        const horsChef = r.promoteursHorsChef.filter((p) => !aRecherche || normaliser(p.displayName).includes(q));
        return { r, directeurs, chefs, horsChef };
      })
      .filter(
        (x) => x.chefs.length > 0 || x.directeurs.length > 0 || x.horsChef.length > 0 || (!aRecherche && (regionId === x.r.id || sansCarte)),
      );
  }, [regions, regionId, aRecherche, q]);

  return (
    // `reducedMotion="user"` : les animations de déplacement sont coupées pour qui a demandé moins de mouvement.
    <MotionConfig reducedMotion="user">
    <section className="rounded-2xl bg-white p-5 shadow-card" aria-labelledby="carte-equipes-titre">
      {/* Le titre de la page est déjà au-dessus : la recherche prend sa place ; le titre reste pour les lecteurs d'écran
          (nom de la section, et cible du focus quand on rouvre la carte). */}
      <h2 id="carte-equipes-titre" ref={titreRef} tabIndex={-1} className="sr-only">
        Les équipes Force de Vente
      </h2>
      {/* Recherche (pleine largeur, haute comme celle de l'annuaire) + CA réalisé / objectif à date à sa droite */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
      <div className="relative min-w-0 flex-1">
        <label htmlFor="carte-recherche" className="sr-only">
          Rechercher un collaborateur
        </label>
        <Search
          size={18}
          className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400"
          aria-hidden
        />
        <input
          id="carte-recherche"
          type="search"
          value={recherche}
          onChange={(e) => setRecherche(e.target.value)}
          placeholder="Rechercher un collaborateur par son nom…"
          className={`h-full min-h-12 w-full rounded-2xl border border-neutral-200 bg-neutral-50 py-3.5 pl-12 pr-4 text-sm dark:border-navy-700 dark:bg-navy-900 ${focus}`}
        />
      </div>
      <CaObjectifADate donnee={data.caADate ?? null} />
      </div>

      {/* Pastilles de filtre par région (sans carte : toutes les régions sont déjà affichées, rien à filtrer) */}
      {!sansCarte ? (
      <div className="mt-3 flex flex-wrap gap-2" role="group" aria-label="Filtrer par région">
        <button
          type="button"
          onClick={() => setRegionId(null)}
          aria-pressed={regionId === null}
          className={`rounded-full border px-3 py-1 text-xs font-medium transition ${focus} ${
            regionId === null
              ? 'border-brand bg-brand text-white'
              : 'border-neutral-200 hover:bg-neutral-100 dark:border-navy-700 dark:hover:bg-navy-800'
          }`}
        >
          Toutes ({total})
        </button>
        {regions.map((r) => (
          <button
            key={r.id}
            type="button"
            onClick={() => basculer(r.id)}
            aria-pressed={regionId === r.id}
            title={r.nom}
            className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition ${focus} ${
              regionId === r.id
                ? 'border-brand bg-brand/10 dark:border-accent'
                : 'border-neutral-200 hover:bg-neutral-100 dark:border-navy-700 dark:hover:bg-navy-800'
            }`}
          >
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: r.couleur }} aria-hidden />
            {r.nom} ({r.nbCollaborateurs})
          </button>
        ))}
      </div>
      ) : null}

      {/* Carte + liste des secteurs : repliées (fondu, réduction, hauteur → 0) dès qu'une région est choisie.
          `initial={false}` : ouvrir la page sur une région n'anime rien. La marge interne laisse la place au halo de la région. */}
      <AnimatePresence initial={false}>
        {regionId === null && !sansCarte ? (
      <motion.div
        key="carte"
        className="-mx-3 mt-1 overflow-hidden px-3 pb-3 pt-3"
        initial={{ opacity: 0, height: 0, scale: 0.94 }}
        animate={{ opacity: 1, height: 'auto', scale: 1 }}
        exit={{ opacity: 0, height: 0, scale: 0.94 }}
        transition={{ duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
      >
        {/* Carte à gauche, panneau des secteurs à droite (empilés sous 1024 px) */}
        <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_24rem]">
        <div className="min-w-0 max-w-2xl">
          <CarteRegionsSvg
            titre="Carte des secteurs commerciaux et de leur nombre de collaborateurs"
            regions={regions.map((r) => ({
              id: r.id,
              code: r.code,
              nom: r.nom,
              valeur: r.nbCollaborateurs,
              selectionnee: regionId === r.id,
              attenuee: regionId !== null && regionId !== r.id,
            }))}
            onRegion={basculer}
          />
        </div>

        {/* Secteurs commerciaux : un appui sélectionne le secteur, comme un appui sur la carte. Chaque secteur montre son
            CA du mois comparé à son objectif (le nombre de collaborateurs est sur la carte et dans les pastilles).
            Aucun titre visible : la liste se comprend seule (nom accessible « Secteurs commerciaux »). */}
        <div className="min-w-0">
        {regions.length === 0 ? (
          <p className="mt-4 text-sm text-neutral-400">Aucune région définie pour le moment.</p>
        ) : (
          <ul aria-label="Secteurs commerciaux" className="flex flex-col gap-2">
            {regions.map((r) => {
              const { titre, sousTitre } = scinderNom(r);
              return (
                <li key={r.id}>
                  <button
                    type="button"
                    onClick={() => basculer(r.id)}
                    aria-pressed={regionId === r.id}
                    title={r.nom}
                    className={`block w-full rounded-xl border px-3 py-3 text-left transition ${focus} ${
                      regionId === r.id
                        ? 'border-brand bg-brand/10 dark:border-accent'
                        : 'border-neutral-100 hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800'
                    }`}
                  >
                    <span className="flex items-center gap-3">
                      <span className="h-3.5 w-3.5 shrink-0 rounded-full" style={{ backgroundColor: r.couleur }} aria-hidden />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-semibold uppercase tracking-wide">{titre}</span>
                        {sousTitre ? <span className="block truncate text-xs text-neutral-500">{sousTitre}</span> : null}
                      </span>
                      <ArrowRight size={16} className="shrink-0 text-neutral-400" aria-hidden />
                    </span>
                    <span className="mt-2 block pl-[1.625rem]">
                      <LigneCa a={r.stats} />
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
        </div>
        </div>
      </motion.div>
        ) : null}
      </AnimatePresence>

      {/* Retour à la carte : visible seulement quand elle est repliée */}
      {regionId !== null && !sansCarte ? (
        <button
          ref={retourRef}
          type="button"
          onClick={() => setRegionId(null)}
          className={`mt-4 inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800 ${focus}`}
        >
          <ArrowLeft size={15} aria-hidden />
          Retour à la carte
        </button>
      ) : null}

      {/* Détail de la région : bilan du mois, direction, chefs de secteur et promoteurs, chacun avec son rôle et son activité */}
      <div aria-live="polite" className="mt-5">
        {detail.length === 0 && aRecherche ? (
          <p className="text-sm text-neutral-400">Aucun collaborateur ne correspond à « {recherche.trim()} ».</p>
        ) : null}
        {detail.map(({ r, directeurs, chefs, horsChef }) => (
          <motion.div
            key={r.id}
            className="mt-4 first:mt-0"
            // Arrive pendant que la carte se replie (léger retard).
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35, delay: 0.15, ease: [0.4, 0, 0.2, 1] }}
          >
            <h3 className="flex flex-wrap items-center gap-2 text-sm font-semibold">
              <span className="h-3 w-3 rounded-full" style={{ backgroundColor: r.couleur }} aria-hidden />
              {r.nom}
              <span className="font-normal text-neutral-500">
                — {r.nbDirecteurs > 0 ? `${pluriel(r.nbDirecteurs, 'directeur')}, ` : ''}
                {pluriel(r.nbChefsSecteur, 'chef')} de secteur, {pluriel(r.nbPromoteurs, 'promoteur')}
              </span>
            </h3>

            {/* Bilan du mois de la région (masqué pendant une recherche : la liste est alors celle des résultats) */}
            {aRecherche ? null : <BilanRegion stats={r.stats} annee={data.periode.annee} mois={data.periode.mois} />}

            {directeurs.length > 0 ? (
              <>
                <h4 className="mt-4 text-xs font-medium uppercase tracking-wide text-neutral-400">Direction</h4>
                <ul className="mt-2 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
                  {directeurs.map((d) => (
                    <li key={d.id} className="rounded-xl border border-neutral-100 p-3 dark:border-navy-700">
                      <div className="flex items-center gap-3">
                        <Photo id={d.id} nom={d.displayName} taille={44} />
                        <div className="min-w-0">
                          <p className="text-sm font-semibold">{d.displayName}</p>
                          <p className="text-xs text-neutral-500">{libelleRole(d.poste, 'Directeur régional')}</p>
                        </div>
                      </div>
                      <LigneActivite a={d} />
                    </li>
                  ))}
                </ul>
              </>
            ) : null}

            <h4 className="mt-4 text-xs font-medium uppercase tracking-wide text-neutral-400">Chefs de secteur et promoteurs</h4>
            {chefs.length === 0 ? (
              <p className="mt-2 text-sm text-neutral-400">
                {horsChef.length > 0 ? 'Aucun chef de secteur dans cette région.' : 'Aucun chef de secteur ni promoteur dans cette région.'}
              </p>
            ) : (
              <ul className="mt-2 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
                {chefs.map((c) => (
                  <li key={c.id} className="rounded-xl border border-neutral-100 p-3 dark:border-navy-700">
                    <div className="flex items-center gap-3">
                      <Photo id={c.id} nom={c.displayName} taille={44} />
                      <div className="min-w-0">
                        {ficheChefSecteur ? (
                          <Link
                            href={`/mon-equipe/${encodeURIComponent(c.id)}`}
                            className={`block rounded-md text-sm font-semibold text-brand hover:underline dark:text-accent ${focus}`}
                          >
                            {c.displayName}
                          </Link>
                        ) : (
                          <p className="text-sm font-semibold">{c.displayName}</p>
                        )}
                        <p className="text-xs text-neutral-500">
                          {libelleRole(c.poste, 'Chef de secteur')} · {c.secteur ? `${c.secteur.nom} · ` : ''}
                          {pluriel(c.nbClients, 'client')}
                        </p>
                      </div>
                    </div>
                    <LigneActivite a={c} />
                    {c.promoteurs.length === 0 ? (
                      <p className="mt-2 text-xs text-neutral-400">Aucun promoteur.</p>
                    ) : (
                      <ul className="mt-3 flex flex-col gap-3 border-t border-neutral-100 pt-3 dark:border-navy-700">
                        {c.promoteurs.map((p) => (
                          <li key={p.id} className="text-xs">
                            <div className="flex items-center gap-2.5">
                              <Photo id={p.id} nom={p.displayName} taille={32} />
                              <div className="min-w-0 flex-1">
                                <div className="flex items-baseline justify-between gap-2">
                                  {fichePromoteur ? (
                                    <Link
                                      href={`/mon-equipe/promoteur/${encodeURIComponent(p.id)}`}
                                      className={`min-w-0 truncate rounded-md text-sm font-medium hover:underline ${focus}`}
                                    >
                                      {p.displayName}
                                    </Link>
                                  ) : (
                                    <span className="min-w-0 truncate text-sm font-medium">{p.displayName}</span>
                                  )}
                                  <span className="shrink-0 text-neutral-500">{pluriel(p.nbClients, 'client')}</span>
                                </div>
                                <p className="text-neutral-500">{libelleRole(p.poste, 'Promoteur')}</p>
                              </div>
                            </div>
                            <LigneActivite a={p} />
                          </li>
                        ))}
                      </ul>
                    )}
                  </li>
                ))}
              </ul>
            )}

            {horsChef.length > 0 ? (
              <>
                <h4 className="mt-4 text-xs font-medium uppercase tracking-wide text-neutral-400">
                  Autres promoteurs de la région
                </h4>
                <ul className="mt-2 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-3">
                  {horsChef.map((p) => (
                    <li key={p.id} className="rounded-xl border border-neutral-100 p-3 text-xs dark:border-navy-700">
                      <div className="flex items-center gap-2.5">
                        <Photo id={p.id} nom={p.displayName} taille={32} />
                        <div className="min-w-0 flex-1">
                          <div className="flex items-baseline justify-between gap-2">
                            {fichePromoteur ? (
                              <Link
                                href={`/mon-equipe/promoteur/${encodeURIComponent(p.id)}`}
                                className={`min-w-0 truncate rounded-md text-sm font-medium hover:underline ${focus}`}
                              >
                                {p.displayName}
                              </Link>
                            ) : (
                              <span className="min-w-0 truncate text-sm font-medium">{p.displayName}</span>
                            )}
                            <span className="shrink-0 text-neutral-500">{pluriel(p.nbClients, 'client')}</span>
                          </div>
                          <p className="text-neutral-500">
                            {libelleRole(p.poste, 'Promoteur')} · {p.chef ? `chef de secteur : ${p.chef}` : 'sans chef de secteur'}
                          </p>
                        </div>
                      </div>
                      <LigneActivite a={p} />
                    </li>
                  ))}
                </ul>
              </>
            ) : null}
          </motion.div>
        ))}
      </div>
    </section>
    </MotionConfig>
  );
}
