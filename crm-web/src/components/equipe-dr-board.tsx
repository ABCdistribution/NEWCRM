'use client';

// « Mon équipe » du directeur régional : menu déroulant « Chefs de secteur » / « Promoteurs » + filtre de région.
import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { ChevronRight, SlidersHorizontal } from 'lucide-react';
import { Avatar } from './avatar';
import { AvertissementIncomplet, CaObjectif, CARTE, FOCUS, ListePromoteurs, Pastille, initiales } from './equipe-ui';
import { resumeEcarts, LIBELLE_STATUT_RAPPORT, type CsCarte, type PromoLigne } from '@/lib/equipe-utils';

type Vue = 'cs' | 'promoteurs';

export function EquipeDrBoard({ chefs, promos }: { chefs: CsCarte[]; promos: PromoLigne[] }) {
  const [vue, setVue] = useState<Vue>('cs');
  const [region, setRegion] = useState('toutes');
  const [ouvert, setOuvert] = useState(false);
  const zone = useRef<HTMLDivElement>(null);

  // Régions tirées des données (UserRow.region).
  const regions = useMemo(
    () => [...new Set([...chefs.map((c) => c.regionNom), ...promos.map((p) => p.regionNom)].filter((r): r is string => !!r))].sort((a, b) => a.localeCompare(b)),
    [chefs, promos],
  );

  // Fermeture du popover : Échap ou clic à l'extérieur.
  useEffect(() => {
    if (!ouvert) return;
    const clavier = (e: KeyboardEvent) => e.key === 'Escape' && setOuvert(false);
    const clic = (e: MouseEvent) => zone.current && !zone.current.contains(e.target as Node) && setOuvert(false);
    document.addEventListener('keydown', clavier);
    document.addEventListener('mousedown', clic);
    return () => {
      document.removeEventListener('keydown', clavier);
      document.removeEventListener('mousedown', clic);
    };
  }, [ouvert]);

  const csFiltres = chefs.filter((c) => region === 'toutes' || c.regionNom === region);
  const promosFiltres = promos.filter((p) => region === 'toutes' || p.regionNom === region);
  const nbFiltres = region !== 'toutes' ? 1 : 0;
  const champ = `rounded-xl border border-neutral-200 bg-white px-3 py-2.5 text-sm shadow-card dark:border-navy-700 dark:bg-navy-950 ${FOCUS}`;

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-2xl font-bold">Mon équipe</h1>
        <p className="text-sm text-neutral-500">
          {csFiltres.length} chef{csFiltres.length > 1 ? 's' : ''} de secteur · {promosFiltres.length} promoteur{promosFiltres.length > 1 ? 's' : ''}
          {region !== 'toutes' ? ` · ${region}` : ''}
        </p>
      </div>

      <div className="flex items-center gap-2">
        <label className="sr-only" htmlFor="equipe-vue">Afficher</label>
        <select id="equipe-vue" value={vue} onChange={(e) => setVue(e.target.value as Vue)} className={`${champ} min-w-0 flex-1 sm:max-w-xs`}>
          <option value="cs">Chefs de secteur</option>
          <option value="promoteurs">Promoteurs</option>
        </select>
        <div ref={zone} className="relative">
          <button
            type="button"
            onClick={() => setOuvert((o) => !o)}
            aria-expanded={ouvert}
            aria-haspopup="dialog"
            aria-label={nbFiltres ? `Filtres (${nbFiltres} actif)` : 'Filtres'}
            className={`relative ${champ}`}
          >
            <SlidersHorizontal size={16} aria-hidden />
            {nbFiltres ? (
              <span className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-brand text-[10px] font-bold text-white">{nbFiltres}</span>
            ) : null}
          </button>
          {ouvert ? (
            <div role="dialog" aria-label="Filtres" className="absolute right-0 z-30 mt-2 w-64 rounded-2xl border border-neutral-200 bg-white p-4 shadow-xl dark:border-navy-700 dark:bg-navy-900">
              <label htmlFor="equipe-region" className="text-xs font-semibold uppercase tracking-wide text-neutral-400">Région</label>
              <select id="equipe-region" value={region} onChange={(e) => setRegion(e.target.value)} className={`${champ} mt-1.5 w-full`}>
                <option value="toutes">Toutes les régions</option>
                {regions.map((r) => (
                  <option key={r} value={r}>{r}</option>
                ))}
              </select>
              <div className="mt-3 flex justify-between gap-2">
                <button type="button" onClick={() => setRegion('toutes')} className={`rounded-lg px-3 py-1.5 text-sm text-neutral-500 hover:underline ${FOCUS}`}>
                  Réinitialiser
                </button>
                <button type="button" onClick={() => setOuvert(false)} className={`rounded-lg bg-brand px-3 py-1.5 text-sm font-medium text-white ${FOCUS}`}>
                  Appliquer
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      <AvertissementIncomplet actif={chefs.some((c) => c.incomplet) || promos.some((p) => p.incomplet)} />

      {vue === 'cs' ? (
        csFiltres.length === 0 ? (
          <p className={`${CARTE} px-5 py-8 text-center text-sm text-neutral-400`}>Aucun chef de secteur pour ce filtre.</p>
        ) : (
          <ul className="grid grid-cols-1 gap-3 lg:grid-cols-2">
            {csFiltres.map((c) => (
              <li key={c.id}>
                <Link href={`/mon-equipe/${c.id}`} className={`group block h-full ${CARTE} p-4 transition hover:shadow-md ${FOCUS}`}>
                  <div className="flex items-center gap-3">
                    <Avatar initials={initiales(c.nom)} size={42} />
                    <div className="min-w-0 flex-1">
                      <h3 className="truncate font-semibold">{c.nom}</h3>
                      <p className="truncate text-xs text-neutral-500">
                        {c.regionNom ? `${c.regionNom} · ` : ''}{c.secteur} · {c.nbPromoteurs} promoteur{c.nbPromoteurs > 1 ? 's' : ''}
                      </p>
                    </div>
                    <ChevronRight size={18} className="shrink-0 text-neutral-300 transition group-hover:text-brand" aria-hidden />
                  </div>
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {c.prevuRenseigne === null ? (
                      <Pastille>Prévision : n/d</Pastille>
                    ) : c.prevuRenseigne ? (
                      <Pastille ton="ok">Prévision enregistrée</Pastille>
                    ) : (
                      <Pastille>Prévision non renseignée</Pastille>
                    )}
                    {c.statut === 'EN_COURS' ? <Pastille ton="cours">Rapport en cours</Pastille> : c.statut === 'VALIDE' || c.statut === 'VALIDE_AUTO' ? <Pastille ton="ok">{LIBELLE_STATUT_RAPPORT[c.statut]}</Pastille> : null}
                  </div>
                  <p className="mt-2 text-xs text-neutral-500">
                    {c.nbPrevues != null ? `Prévu ${c.nbPrevues} · Réalisé ${c.nbRealisees ?? 0} · ` : ''}
                    {resumeEcarts(c.ecarts)}
                  </p>
                  <CaObjectif ca={c.ca} objectif={c.objectif} className="mt-3" />
                </Link>
              </li>
            ))}
          </ul>
        )
      ) : (
        <ListePromoteurs promos={promosFiltres} avecChef vide="Aucun promoteur pour ce filtre." />
      )}
    </div>
  );
}
