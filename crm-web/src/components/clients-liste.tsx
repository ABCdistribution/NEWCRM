import Link from 'next/link';
import { ChevronRight } from 'lucide-react';
import type { ClientListe } from '@/lib/clients-liste';
import { ActiveBadge } from './badges';
import { ClassBadge } from './class-badge';

/** Un client créé depuis moins de 30 jours porte la pastille « Nouveau ». */
const JOURS_NOUVEAU = 30;

const estNouveau = (createdAt: string, maintenant: number) => {
  const t = Date.parse(createdAt);
  return Number.isFinite(t) && maintenant - t < JOURS_NOUVEAU * 24 * 3600 * 1000;
};

const TH = 'px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wider text-neutral-500';

/**
 * Liste des clients : enseigne (pastille « Nouveau »), code AS400, ville et code postal, niveau, état. Toute la ligne
 * ouvre la fiche (`/clients/[id]`). Composant serveur : aucun état, que du rendu des lignes déjà filtrées par l'API.
 */
export function ClientsListe({ clients, maintenant = Date.now() }: { clients: ClientListe[]; maintenant?: number }) {
  return (
    <div className="overflow-x-auto rounded-2xl bg-white shadow-card">
      <table className="w-full min-w-[44rem] text-sm">
        <thead>
          <tr className="border-b border-neutral-100">
            <th scope="col" className={TH}>
              Enseigne
            </th>
            <th scope="col" className={TH}>
              Code AS400
            </th>
            <th scope="col" className={TH}>
              Ville / CP
            </th>
            <th scope="col" className={TH}>
              Niveau
            </th>
            <th scope="col" className={TH}>
              Statut
            </th>
            <th scope="col" className="w-10">
              <span className="sr-only">Ouvrir</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {clients.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-10 text-center text-neutral-400">
                Aucun client pour ces filtres.
              </td>
            </tr>
          ) : (
            clients.map((c) => (
              <tr key={c.id} className="relative border-b border-neutral-100 transition last:border-0 hover:bg-neutral-50">
                <td className="px-4 py-3">
                  <Link
                    href={`/clients/${encodeURIComponent(c.id)}`}
                    className="font-semibold after:absolute after:inset-0 focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-brand"
                  >
                    {c.enseigne || c.raisonSociale}
                  </Link>
                  {estNouveau(c.createdAt, maintenant) ? (
                    <span className="ml-2 rounded-full bg-badge px-2 py-0.5 text-[11px] font-semibold text-brand">Nouveau</span>
                  ) : null}
                </td>
                <td className="px-4 py-3 font-mono text-xs text-neutral-500">{c.codeAs400}</td>
                <td className="px-4 py-3 uppercase text-neutral-700">
                  {[c.ville, c.codePostal].filter(Boolean).join(' · ') || '—'}
                </td>
                <td className="px-4 py-3">
                  {c.niveauClass ? <ClassBadge value={c.niveauClass} /> : <span className="text-neutral-300">—</span>}
                </td>
                <td className="px-4 py-3">
                  <ActiveBadge active={c.actif} />
                </td>
                <td className="px-2 py-3 text-neutral-300">
                  <ChevronRight size={16} aria-hidden />
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
