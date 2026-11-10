// Briques d'affichage de « Mon équipe » (composants serveur : aucun état, que du rendu).
import Link from 'next/link';
import { ChevronRight, ChevronLeft } from 'lucide-react';
import { Avatar } from './avatar';
import { EUR, type PromoLigne } from '@/lib/equipe-utils';

export const FOCUS = 'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';
export const CARTE = 'rounded-2xl bg-white shadow-card';
export const BOUTON_LIEN = `inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800 ${FOCUS}`;

export function initiales(nom: string): string {
  return nom
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((m) => m[0]?.toUpperCase())
    .join('');
}

/** « CA réalisé / objectif » en euros, avec barre de progression (jamais de pourcentage affiché). */
export function CaObjectif({ ca, objectif, className = '' }: { ca: number | null; objectif: number | null; className?: string }) {
  const largeur = objectif && objectif > 0 ? Math.min(100, Math.max(0, ((ca ?? 0) / objectif) * 100)) : 0;
  return (
    <div className={className}>
      <p className="text-right text-sm tabular-nums">
        <span className="font-semibold text-brand dark:text-accent">{ca != null ? EUR.format(ca) : '—'}</span>
        <span className="text-neutral-400"> / {objectif != null ? EUR.format(objectif) : '—'}</span>
      </p>
      <div
        className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-neutral-100 dark:bg-navy-700"
        role="progressbar"
        aria-label="CA réalisé sur objectif"
        aria-valuemin={0}
        aria-valuemax={objectif ?? 0}
        aria-valuenow={Math.round(ca ?? 0)}
        aria-valuetext={`${ca != null ? EUR.format(ca) : '—'} sur ${objectif != null ? EUR.format(objectif) : 'objectif non défini'}`}
      >
        <div className="h-full rounded-full bg-brand" style={{ width: `${largeur}%` }} />
      </div>
    </div>
  );
}

export function Pastille({ children, ton = 'neutre' }: { children: React.ReactNode; ton?: 'neutre' | 'ok' | 'cours' }) {
  const cls =
    ton === 'ok'
      ? 'bg-emerald-500/12 text-emerald-700 dark:text-emerald-400'
      : ton === 'cours'
        ? 'bg-brand/12 text-brand dark:text-accent'
        : 'bg-neutral-100 text-neutral-500 dark:bg-navy-800 dark:text-neutral-300';
  return <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${cls}`}>{children}</span>;
}

/**
 * Bandeau affiché quand des chiffres manquent parce qu'une requête à l'API a échoué (et non parce qu'ils sont vides) :
 * sans lui, un « — » ou un « n/d » ne se distingue pas d'une vraie absence de donnée.
 */
export function AvertissementIncomplet({ actif }: { actif: boolean }) {
  if (!actif) return null;
  return (
    <p role="status" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
      Certains chiffres n&apos;ont pas pu être chargés (le serveur n&apos;a pas répondu à toutes les requêtes). Les valeurs
      affichées « — » ou « n/d » peuvent donc être incomplètes : rechargez la page dans un instant.
    </p>
  );
}

/** Une ligne de la liste des promoteurs (clic = fiche du promoteur). */
export function LignePromoteur({ p, avecChef = false }: { p: PromoLigne; avecChef?: boolean }) {
  return (
    <li>
      <Link
        href={`/mon-equipe/promoteur/${p.id}`}
        className={`group block ${CARTE} p-4 transition hover:shadow-md ${FOCUS}`}
      >
        <div className="flex items-center gap-3">
          <Avatar initials={initiales(p.nom)} size={40} />
          <div className="min-w-0 flex-1">
            <h3 className="truncate font-semibold">
              {p.nom}
              {avecChef && p.csNom ? <span className="text-xs font-medium text-neutral-400"> · {p.csNom}</span> : null}
            </h3>
            <p className="truncate text-xs text-neutral-500">
              {p.nbClients != null ? `${p.nbClients} client${p.nbClients > 1 ? 's' : ''}` : 'Clients : n/d'}
              {p.visitesPrevues != null ? ` · ${p.visitesFaites}/${p.visitesPrevues} visites cette semaine` : ''}
            </p>
          </div>
          <CaObjectif ca={p.ca} objectif={p.objectif} className="w-40 shrink-0 sm:w-52" />
          <ChevronRight size={18} className="hidden shrink-0 text-neutral-300 transition group-hover:text-brand sm:block" aria-hidden />
        </div>
        {p.jourPrevues != null ? (
          <p className="mt-2.5 text-xs text-neutral-500">
            Aujourd&apos;hui : {p.jourFaites}/{p.jourPrevues} visite{p.jourPrevues > 1 ? 's' : ''} faite{(p.jourFaites ?? 0) > 1 ? 's' : ''}
          </p>
        ) : null}
      </Link>
    </li>
  );
}

/** Liste de promoteurs (état vide inclus). */
export function ListePromoteurs({ promos, avecChef = false, vide }: { promos: PromoLigne[]; avecChef?: boolean; vide: string }) {
  if (promos.length === 0) {
    return <p className={`${CARTE} px-5 py-8 text-center text-sm text-neutral-400`}>{vide}</p>;
  }
  return (
    <ul className="flex flex-col gap-3">
      {promos.map((p) => (
        <LignePromoteur key={p.id} p={p} avecChef={avecChef} />
      ))}
    </ul>
  );
}

export type Onglet = { id: string; label: string };

/** Onglets portés par l'URL (`?onglet=`) : liens accessibles, `role="tab"` et `aria-selected`. */
export function Onglets({ onglets, actif, hrefDe, label }: { onglets: Onglet[]; actif: string; hrefDe: (id: string) => string; label: string }) {
  return (
    <div role="tablist" aria-label={label} className="flex gap-1 overflow-x-auto rounded-xl bg-neutral-100 p-1 dark:bg-navy-800">
      {onglets.map((o) => (
        <Link
          key={o.id}
          role="tab"
          aria-selected={o.id === actif}
          href={hrefDe(o.id)}
          scroll={false}
          className={`flex-1 whitespace-nowrap rounded-lg px-4 py-2 text-center text-sm font-medium transition ${FOCUS} ${
            o.id === actif ? 'bg-white text-brand shadow-card dark:bg-navy-950 dark:text-accent' : 'text-neutral-500 hover:text-neutral-700 dark:text-neutral-300'
          }`}
        >
          {o.label}
        </Link>
      ))}
    </div>
  );
}

/** Navigation « semaine précédente / suivante » (liens `?semaine=`). */
export function NavSemaine({ libelle, hrefPrec, hrefSuiv }: { libelle: string; hrefPrec: string; hrefSuiv: string }) {
  const btn = `rounded-lg border border-neutral-200 p-2 text-neutral-500 transition hover:bg-neutral-50 dark:border-navy-700 dark:hover:bg-navy-800 ${FOCUS}`;
  return (
    <div className="flex items-center gap-2">
      <Link href={hrefPrec} scroll={false} className={btn} aria-label="Semaine précédente">
        <ChevronLeft size={16} />
      </Link>
      <span className="min-w-40 text-center text-sm font-medium" aria-live="polite">{libelle}</span>
      <Link href={hrefSuiv} scroll={false} className={btn} aria-label="Semaine suivante">
        <ChevronRight size={16} />
      </Link>
    </div>
  );
}
