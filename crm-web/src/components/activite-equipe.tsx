import { CalendarCheck, ShoppingCart, Target } from 'lucide-react';
import type { Activite } from '@/lib/carte';
import { euros, libellePeriode, niveauObjectif, phraseObjectif, type NiveauObjectif } from '@/lib/activite';

// Couleurs SÉMANTIQUES de statut (objectif atteint / en retard / très en retard), seules couleurs en dur autorisées :
// l'état est aussi écrit en clair (pourcentage et phrase pour les lecteurs d'écran), la couleur n'est jamais seule.
const COULEUR_BARRE: Record<NiveauObjectif, string> = {
  bon: 'bg-emerald-500',
  moyen: 'bg-amber-500',
  bas: 'bg-red-500',
  aucun: 'bg-neutral-300',
};
const COULEUR_TEXTE: Record<NiveauObjectif, string> = {
  bon: 'text-emerald-700',
  moyen: 'text-amber-700',
  bas: 'text-red-700',
  aucun: 'text-neutral-500',
};

const pluriel = (n: number, mot: string) => `${n} ${mot}${n > 1 ? 's' : ''}`;

/** Barre d'avancement du CA sur l'objectif (plafonnée à 100 % pour le tracé, le pourcentage réel reste écrit). */
function BarreObjectif({ a }: { a: Pick<Activite, 'ca' | 'objectif' | 'tauxPct'> }) {
  const niveau = niveauObjectif(a.tauxPct);
  return (
    <div
      role="img"
      aria-label={phraseObjectif(a)}
      className="h-1.5 w-full overflow-hidden rounded-full bg-neutral-100 dark:bg-navy-800"
    >
      <div className={`h-full rounded-full ${COULEUR_BARRE[niveau]}`} style={{ width: `${Math.min(100, a.tauxPct ?? 0)}%` }} />
    </div>
  );
}

/** « CA 8 450 € sur 10 000 € · 84 % » ou « CA 8 450 € · objectif non défini ». */
function TexteObjectif({ a }: { a: Pick<Activite, 'ca' | 'objectif' | 'tauxPct'> }) {
  const niveau = niveauObjectif(a.tauxPct);
  return a.objectif == null || a.tauxPct == null ? (
    <span className="text-neutral-500">
      CA {euros(a.ca)} · <span className="text-neutral-400">objectif non défini</span>
    </span>
  ) : (
    <span>
      CA <b className="font-semibold">{euros(a.ca)}</b> sur {euros(a.objectif)} ·{' '}
      <b className={`font-semibold ${COULEUR_TEXTE[niveau]}`}>{a.tauxPct} %</b>
    </span>
  );
}

/** Activité d'une personne sur une ligne : visites, commandes, CA et objectif, avec sa barre (liste des membres). */
export function LigneActivite({ a }: { a: Activite }) {
  return (
    <div className="mt-1.5">
      <p className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-neutral-600 dark:text-neutral-300">
        <span>{pluriel(a.visites, 'visite')}</span>
        <span>{pluriel(a.commandes, 'commande')}</span>
        <TexteObjectif a={a} />
      </p>
      <div className="mt-1">
        <BarreObjectif a={a} />
      </div>
    </div>
  );
}

function Tuile({ icone, libelle, valeur }: { icone: React.ReactNode; libelle: string; valeur: string }) {
  return (
    <div className="rounded-xl bg-neutral-50 px-3 py-2.5 dark:bg-navy-800">
      <p className="flex items-center gap-1.5 text-xs text-neutral-500">
        {icone}
        {libelle}
      </p>
      <p className="mt-0.5 text-lg font-bold tabular-nums">{valeur}</p>
    </div>
  );
}

/** Bilan du mois d'une région : visites, commandes, CA, et CA comparé à l'objectif (somme de ceux de ses membres). */
export function BilanRegion({ stats, annee, mois }: { stats: Activite; annee: number; mois: number }) {
  const niveau = niveauObjectif(stats.tauxPct);
  return (
    <div className="mt-3 rounded-xl border border-neutral-100 p-3 dark:border-navy-700">
      <p className="text-xs font-medium uppercase tracking-wide text-neutral-400">Activité · {libellePeriode(annee, mois)}</p>
      <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-3">
        <Tuile icone={<CalendarCheck size={13} aria-hidden />} libelle="Visites" valeur={String(stats.visites)} />
        <Tuile icone={<ShoppingCart size={13} aria-hidden />} libelle="Commandes" valeur={String(stats.commandes)} />
        <Tuile icone={<Target size={13} aria-hidden />} libelle="CA du mois" valeur={euros(stats.ca)} />
      </div>
      <div className="mt-3">
        <div className="flex flex-wrap items-baseline justify-between gap-2 text-sm">
          <span className="font-medium">CA comparé à l&apos;objectif</span>
          {stats.objectif == null || stats.tauxPct == null ? (
            <span className="text-neutral-500">Objectif non défini pour cette région</span>
          ) : (
            <span>
              <b className="tabular-nums">{euros(stats.ca)}</b> sur {euros(stats.objectif)} ·{' '}
              <b className={`tabular-nums ${COULEUR_TEXTE[niveau]}`}>{stats.tauxPct} %</b>
            </span>
          )}
        </div>
        <div className="mt-1.5">
          <BarreObjectif a={stats} />
        </div>
      </div>
    </div>
  );
}
