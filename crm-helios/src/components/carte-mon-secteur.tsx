'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { MapPin, Sprout, Store } from 'lucide-react';
import { projeter, type FondDepartement } from '@/lib/carte-geo';
import type { CarteClient, CarteProspect, CarteSecteurData } from '@/lib/carte';
import type { ClientRow } from '@/lib/api';
import { ClassBadge } from './class-badge';
import { CarteFranceSvg, type PointSvg } from './carte-france-svg';

const PAGE = 100;

const focus =
  'outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1 dark:focus-visible:ring-accent';

type Selection = { type: 'client' | 'prospect'; id: string } | null;

/**
 * Carte en mode POINTS pour le secteur du chef de secteur : clients (cercles) et prospects (losanges)
 * sur le fond de départements, avec bascules, filtre par promoteur, fiche et liste d'équivalent clavier.
 * `repli` : clients non géolocalisés (endpoint /clients) affichés en liste quand aucun point n'existe.
 */
export function CarteMonSecteur({
  data,
  fond,
  repli,
  repliErreur,
}: {
  data: CarteSecteurData;
  fond: FondDepartement[];
  repli: ClientRow[] | null;
  repliErreur: string | null;
}) {
  const [voirClients, setVoirClients] = useState(true);
  const [voirProspects, setVoirProspects] = useState(true);
  const [promoteurId, setPromoteurId] = useState('');
  const [selection, setSelection] = useState<Selection>(null);
  const [limite, setLimite] = useState(PAGE);

  const promoteurs = useMemo(() => {
    const m = new Map<string, string>();
    for (const c of data.clients) if (c.promoteur) m.set(c.promoteur.id, c.promoteur.displayName);
    return [...m.entries()].sort((a, b) => a[1].localeCompare(b[1], 'fr'));
  }, [data.clients]);

  const filtreActif = promoteurId !== '';
  const clients = useMemo(
    () => (voirClients ? data.clients.filter((c) => !filtreActif || c.promoteur?.id === promoteurId) : []),
    [data.clients, voirClients, filtreActif, promoteurId],
  );
  // Un prospect n'a pas de promoteur : il est masqué dès qu'un promoteur est choisi.
  const prospects = useMemo(
    () => (voirProspects && !filtreActif ? data.prospects : []),
    [data.prospects, voirProspects, filtreActif],
  );

  const points: PointSvg[] = useMemo(() => {
    const sel = (t: 'client' | 'prospect', id: string) => selection?.type === t && selection.id === id;
    return [
      ...clients.map((c) => {
        const [x, y] = projeter(c.longitude, c.latitude);
        return { id: c.id, type: 'client' as const, x, y, attenue: false, selectionne: sel('client', c.id) };
      }),
      ...prospects.map((p) => {
        const [x, y] = projeter(p.longitude, p.latitude);
        return { id: p.id, type: 'prospect' as const, x, y, attenue: false, selectionne: sel('prospect', p.id) };
      }),
    ];
  }, [clients, prospects, selection]);

  const choisi: { client?: CarteClient; prospect?: CarteProspect } = useMemo(() => {
    if (!selection) return {};
    return selection.type === 'client'
      ? { client: data.clients.find((c) => c.id === selection.id) }
      : { prospect: data.prospects.find((p) => p.id === selection.id) };
  }, [selection, data]);

  const choisir = (type: 'client' | 'prospect', id: string) =>
    setSelection((s) => (s?.type === type && s.id === id ? null : { type, id }));

  const aucunPoint = data.clients.length === 0 && data.prospects.length === 0;
  const lignes: { type: 'client' | 'prospect'; id: string }[] = [
    ...clients.map((c) => ({ type: 'client' as const, id: c.id })),
    ...prospects.map((p) => ({ type: 'prospect' as const, id: p.id })),
  ];
  const clientParId = new Map(data.clients.map((c) => [c.id, c]));
  const prospectParId = new Map(data.prospects.map((p) => [p.id, p]));

  const bascule = (actif: boolean, set: (v: boolean) => void, libelle: string, nb: number, Icone: typeof Store) => (
    <button
      type="button"
      onClick={() => set(!actif)}
      aria-pressed={actif}
      className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition ${focus} ${
        actif
          ? 'border-brand bg-brand text-white'
          : 'border-neutral-200 hover:bg-neutral-100 dark:border-navy-700 dark:hover:bg-navy-800'
      }`}
    >
      <Icone size={13} aria-hidden />
      {libelle} ({nb})
    </button>
  );

  return (
    <section className="rounded-2xl bg-white p-5 shadow-card" aria-labelledby="carte-secteur-titre">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 id="carte-secteur-titre" className="flex items-center gap-2 text-lg font-semibold">
          <MapPin size={18} className="text-brand dark:text-accent" aria-hidden />
          Mon secteur sur la carte
        </h2>
        <div className="flex flex-wrap items-center gap-2">
          {bascule(voirClients, setVoirClients, 'Clients', data.clients.length, Store)}
          {bascule(voirProspects, setVoirProspects, 'Prospects', data.prospects.length, Sprout)}
          <label className="flex items-center gap-2 text-xs text-neutral-500">
            Promoteur
            <select
              value={promoteurId}
              onChange={(e) => setPromoteurId(e.target.value)}
              disabled={promoteurs.length === 0}
              className={`rounded-lg border border-neutral-200 bg-transparent px-2 py-1 text-xs text-inherit dark:border-navy-700 dark:bg-navy-950 ${focus}`}
            >
              <option value="">Tous</option>
              {promoteurs.map(([id, nom]) => (
                <option key={id} value={id}>
                  {nom}
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>

      {data.tronque ? (
        <p className="mt-3 rounded-lg bg-amber-500/10 px-3 py-2 text-xs text-amber-600" role="status">
          Affichage limité aux {data.limite.toLocaleString('fr-FR')} premiers points géolocalisés : la carte est incomplète.
        </p>
      ) : null}

      {aucunPoint ? (
        <div className="mt-4">
          <p className="rounded-lg bg-neutral-50 px-4 py-3 text-sm text-neutral-600 dark:bg-navy-800 dark:text-neutral-300" role="status">
            Aucun client géolocalisé pour l&apos;instant. Les points apparaîtront ici dès que les fiches auront des coordonnées.
          </p>
          {repliErreur ? (
            <p className="mt-3 text-sm text-red-500">{repliErreur}</p>
          ) : repli && repli.length > 0 ? (
            <>
              <h3 className="mt-4 text-sm font-semibold">Mes clients (sans carte)</h3>
              <ul className="mt-2 grid grid-cols-1 gap-x-6 md:grid-cols-2">
                {repli.map((c) => (
                  <li key={c.id} className="flex items-center gap-2 border-b border-neutral-100 py-2 text-sm dark:border-navy-700">
                    <Link
                      href={`/pilotage/clients/${encodeURIComponent(c.id)}`}
                      className={`min-w-0 flex-1 truncate rounded-md font-medium text-brand hover:underline dark:text-accent ${focus}`}
                    >
                      {c.enseigne || c.raisonSociale}
                    </Link>
                    <ClassBadge value={c.niveauClass} size="xs" />
                    {c.ville ? <span className="shrink-0 text-xs text-neutral-400">{c.ville}</span> : null}
                  </li>
                ))}
              </ul>
            </>
          ) : null}
        </div>
      ) : (
        <>
          <div className="mt-4 grid grid-cols-1 gap-5 lg:grid-cols-5">
            <div className="lg:col-span-3">
              <CarteFranceSvg
                departements={fond}
                titre="Carte de France des clients (cercles) et prospects (losanges) de mon secteur"
                points={points}
                onPoint={choisir}
              />
              <p className="mt-1 flex justify-center gap-4 text-xs text-neutral-500">
                <span className="inline-flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rounded-full bg-brand" aria-hidden /> Client
                </span>
                <span className="inline-flex items-center gap-1.5">
                  <span className="h-2.5 w-2.5 rotate-45 bg-accent" aria-hidden /> Prospect
                </span>
              </p>
            </div>

            {/* Fiche du point sélectionné */}
            <div className="lg:col-span-2" aria-live="polite">
              {choisi.client || choisi.prospect ? (
                <div className="rounded-xl border border-neutral-100 p-4 dark:border-navy-700">
                  {choisi.client ? (
                    <>
                      <p className="text-xs font-medium text-neutral-500">Client</p>
                      <p className="mt-0.5 flex items-center gap-2 font-semibold">
                        {choisi.client.nom}
                        <ClassBadge value={choisi.client.classe} />
                      </p>
                      <p className="text-sm text-neutral-500">{lieu(choisi.client)}</p>
                      <p className="mt-2 text-sm">
                        Promoteur :{' '}
                        {choisi.client.promoteur ? (
                          <Link
                            href={`/pilotage/mon-equipe/promoteur/${encodeURIComponent(choisi.client.promoteur.id)}`}
                            className={`rounded-md font-medium text-brand hover:underline dark:text-accent ${focus}`}
                          >
                            {choisi.client.promoteur.displayName}
                          </Link>
                        ) : (
                          <span className="text-neutral-400">aucun</span>
                        )}
                      </p>
                      <Link
                        href={`/pilotage/clients/${encodeURIComponent(choisi.client.id)}`}
                        className={`mt-3 inline-block rounded-md text-sm font-medium text-brand underline dark:text-accent ${focus}`}
                      >
                        Voir la fiche
                      </Link>
                    </>
                  ) : choisi.prospect ? (
                    <>
                      <p className="text-xs font-medium text-neutral-500">Prospect</p>
                      <p className="mt-0.5 font-semibold">{choisi.prospect.nom}</p>
                      <p className="text-sm text-neutral-500">{lieu(choisi.prospect)}</p>
                      <p className="mt-2 text-sm">
                        Statut : <span className="font-medium">{libelleStatut(choisi.prospect.statut)}</span>
                      </p>
                      {choisi.prospect.chefSecteur ? (
                        <p className="text-sm text-neutral-500">Suivi par {choisi.prospect.chefSecteur.displayName}</p>
                      ) : null}
                      <Link
                        href={`/pilotage/prospects/${encodeURIComponent(choisi.prospect.id)}`}
                        className={`mt-3 inline-block rounded-md text-sm font-medium text-brand underline dark:text-accent ${focus}`}
                      >
                        Voir la fiche
                      </Link>
                    </>
                  ) : null}
                </div>
              ) : (
                <p className="rounded-xl border border-dashed border-neutral-200 p-4 text-sm text-neutral-500 dark:border-navy-700">
                  Cliquez sur un point ou sur une ligne de la liste pour afficher la fiche.
                </p>
              )}
              {filtreActif && voirProspects ? (
                <p className="mt-2 text-xs text-neutral-500">
                  Les prospects n&apos;ont pas de promoteur : ils sont masqués quand un promoteur est choisi.
                </p>
              ) : null}
            </div>
          </div>

          {/* Liste (équivalent clavier de la carte) */}
          <h3 className="mt-5 text-sm font-semibold">
            Liste ({lignes.length})
          </h3>
          {lignes.length === 0 ? (
            <p className="mt-2 text-sm text-neutral-400">Rien à afficher avec ces filtres.</p>
          ) : (
            <>
              <ul className="mt-2 grid grid-cols-1 gap-x-6 md:grid-cols-2">
                {lignes.slice(0, limite).map((l) => {
                  const c = l.type === 'client' ? clientParId.get(l.id) : undefined;
                  const p = l.type === 'prospect' ? prospectParId.get(l.id) : undefined;
                  const actif = selection?.type === l.type && selection.id === l.id;
                  return (
                    <li key={`${l.type}-${l.id}`} className="border-b border-neutral-100 dark:border-navy-700">
                      <button
                        type="button"
                        onClick={() => choisir(l.type, l.id)}
                        aria-pressed={actif}
                        className={`flex w-full items-center gap-2 rounded-md px-1 py-2 text-left text-sm ${focus} ${
                          actif ? 'bg-brand/10' : 'hover:bg-neutral-50 dark:hover:bg-navy-800'
                        }`}
                      >
                        {c ? (
                          <Store size={14} className="shrink-0 text-brand dark:text-accent" aria-label="Client" />
                        ) : (
                          <Sprout size={14} className="shrink-0 text-accent" aria-label="Prospect" />
                        )}
                        <span className="min-w-0 flex-1 truncate font-medium">{c?.nom ?? p?.nom}</span>
                        {c ? <ClassBadge value={c.classe} size="xs" /> : null}
                        <span className="shrink-0 text-xs text-neutral-500">
                          {c
                            ? (c.promoteur?.displayName ?? 'Sans promoteur')
                            : p
                              ? libelleStatut(p.statut)
                              : ''}
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
              {lignes.length > limite ? (
                <button
                  type="button"
                  onClick={() => setLimite((n) => n + PAGE)}
                  className={`mt-3 rounded-lg border border-neutral-200 px-3 py-1.5 text-xs font-medium hover:bg-neutral-100 dark:border-navy-700 dark:hover:bg-navy-800 ${focus}`}
                >
                  Afficher {Math.min(PAGE, lignes.length - limite)} lignes de plus
                </button>
              ) : null}
            </>
          )}
        </>
      )}
    </section>
  );
}

function lieu(x: { ville: string | null; codePostal: string | null }) {
  return [x.codePostal, x.ville].filter(Boolean).join(' ') || 'Localité inconnue';
}

function libelleStatut(s: string | null) {
  if (!s) return 'Statut inconnu';
  const t = s.replace(/_/g, ' ').toLowerCase();
  return t.charAt(0).toUpperCase() + t.slice(1);
}
