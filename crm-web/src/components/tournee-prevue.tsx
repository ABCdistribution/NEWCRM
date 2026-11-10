import { ClipboardList } from 'lucide-react';
import type { LigneRapport } from '@/lib/api';

const JOUR_FMT = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });

/** Qualification d'une ligne : visite simple / accompagnement, RDV, soirée étape. */
export function qualification(l: LigneRapport): string {
  return [
    l.adm ? 'Administratif' : l.accompagnement ? 'Accompagnement promoteur' : 'Visite simple',
    l.rdv ? 'RDV' : null,
    l.soireeEtape ? `Soirée étape${l.soireeLieu ? ` — ${l.soireeLieu}` : ''}` : null,
  ]
    .filter(Boolean)
    .join(' · ');
}

/** Liste de lignes de rapport regroupées par jour (lecture seule). */
export function LignesParJour({ lignes, vide }: { lignes: LigneRapport[]; vide: string }) {
  if (lignes.length === 0) return <p className="px-1 py-2 text-xs text-neutral-400">{vide}</p>;
  const parJour = new Map<string, LigneRapport[]>();
  for (const l of [...lignes].sort((a, b) => `${a.jour} ${a.heure ?? ''}`.localeCompare(`${b.jour} ${b.heure ?? ''}`))) {
    parJour.set(l.jour, [...(parJour.get(l.jour) ?? []), l]);
  }
  return (
    <div className="flex flex-col gap-3">
      {[...parJour.entries()].map(([jour, items]) => (
        <div key={jour}>
          <p className="pb-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">{JOUR_FMT.format(new Date(`${jour}T12:00:00`))}</p>
          <ul className="flex flex-col gap-1">
            {items.map((l, i) => (
              <li key={l.id ?? `${jour}-${i}`} className="rounded-lg bg-neutral-50 px-2.5 py-1.5 text-xs dark:bg-navy-800/50">
                <p className="flex flex-wrap items-baseline gap-x-2">
                  {l.heure ? <span className="font-semibold">{l.heure}</span> : null}
                  <span className="font-medium">{l.titre || 'Sans nom'}</span>
                  {l.ville ? <span className="text-neutral-400">{l.ville}</span> : null}
                </p>
                <p className="text-neutral-500">{qualification(l)}</p>
                {l.adresse ? <p className="text-neutral-400">{l.adresse}</p> : null}
                {l.note ? <p className="text-neutral-500">{l.note}</p> : null}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}

/** Tournée prévue de la semaine : la photographie enregistrée, à comparer à la tournée réalisée. */
export function TourneePrevue({ lignes }: { lignes: LigneRapport[] | null }) {
  return (
    <details className="rounded-2xl bg-white px-4 py-3 shadow-card">
      <summary className="flex cursor-pointer select-none items-center gap-2 text-sm font-semibold">
        <ClipboardList size={15} className="text-sky-500" /> Tournée prévue
        <span className="text-xs font-normal text-neutral-400">
          {lignes === null ? 'non renseignée' : `${lignes.length} ligne${lignes.length > 1 ? 's' : ''} · figée`}
        </span>
      </summary>
      <div className="pt-3">
        <LignesParJour lignes={lignes ?? []} vide="La prévision n'a pas été renseignée cette semaine." />
      </div>
    </details>
  );
}
