'use client';

import { useMemo, useState } from 'react';
import { KpiTile } from './kpi-tile';

type Statut = 'PREPARATION' | 'EN_COURS' | 'LIVREE' | 'RETARD';

type Livraison = {
  id: string;
  numero: string;
  client: string;
  ville: string;
  commandeLe: string;
  prevueLe: string;
  transporteur: string;
  colis: number;
  montant: number;
  statut: Statut;
};

const STATUT_LABEL: Record<Statut, string> = {
  PREPARATION: 'Préparation',
  EN_COURS: 'En cours',
  LIVREE: 'Livrée',
  RETARD: 'En retard',
};

const STATUT_STYLE: Record<Statut, string> = {
  PREPARATION: 'bg-neutral-400/15 text-neutral-500',
  EN_COURS: 'bg-sky-500/12 text-sky-600 dark:text-sky-400',
  LIVREE: 'bg-emerald-500/12 text-emerald-600 dark:text-emerald-400',
  RETARD: 'bg-red-500/12 text-red-600 dark:text-red-400',
};

// Jeu de données représentatif (prototype — à brancher sur le suivi transporteur / Minos).
const LIVRAISONS: Livraison[] = [
  { id: 'l1', numero: 'BL-24815', client: 'Leclerc Évry 2', ville: 'Évry', commandeLe: '12 mai', prevueLe: '16 mai', transporteur: 'Geodis', colis: 8, montant: 4210, statut: 'EN_COURS' },
  { id: 'l2', numero: 'BL-24816', client: 'Système U Lyon Vaise', ville: 'Lyon', commandeLe: '11 mai', prevueLe: '15 mai', transporteur: 'DPD', colis: 3, montant: 1890, statut: 'LIVREE' },
  { id: 'l3', numero: 'BL-24817', client: 'Intermarché La Mézière', ville: 'La Mézière', commandeLe: '10 mai', prevueLe: '14 mai', transporteur: 'Heppner', colis: 12, montant: 6320, statut: 'RETARD' },
  { id: 'l4', numero: 'BL-24818', client: 'Auchan Vert Saint-Denis', ville: 'Saint-Denis', commandeLe: '13 mai', prevueLe: '17 mai', transporteur: 'XPO', colis: 5, montant: 2750, statut: 'PREPARATION' },
  { id: 'l5', numero: 'BL-24819', client: 'Carrefour Market Nantes', ville: 'Nantes', commandeLe: '9 mai', prevueLe: '13 mai', transporteur: 'Geodis', colis: 6, montant: 3480, statut: 'LIVREE' },
  { id: 'l6', numero: 'BL-24820', client: 'Cora Bruay', ville: 'Bruay', commandeLe: '12 mai', prevueLe: '16 mai', transporteur: 'Chronopost', colis: 2, montant: 940, statut: 'EN_COURS' },
  { id: 'l7', numero: 'BL-24821', client: 'Auchan Roncq', ville: 'Roncq', commandeLe: '8 mai', prevueLe: '12 mai', transporteur: 'Heppner', colis: 9, montant: 5120, statut: 'RETARD' },
  { id: 'l8', numero: 'BL-24822', client: 'Système U Rennes', ville: 'Rennes', commandeLe: '13 mai', prevueLe: '17 mai', transporteur: 'DPD', colis: 4, montant: 2210, statut: 'PREPARATION' },
  { id: 'l9', numero: 'BL-24823', client: 'Leclerc Blagnac', ville: 'Blagnac', commandeLe: '10 mai', prevueLe: '14 mai', transporteur: 'XPO', colis: 7, montant: 3990, statut: 'EN_COURS' },
  { id: 'l10', numero: 'BL-24824', client: 'Intermarché Vannes', ville: 'Vannes', commandeLe: '9 mai', prevueLe: '13 mai', transporteur: 'Geodis', colis: 5, montant: 2680, statut: 'LIVREE' },
  { id: 'l11', numero: 'BL-24825', client: 'Casino Nice', ville: 'Nice', commandeLe: '14 mai', prevueLe: '19 mai', transporteur: 'Chronopost', colis: 3, montant: 1450, statut: 'PREPARATION' },
  { id: 'l12', numero: 'BL-24826', client: 'Cora Lens', ville: 'Lens', commandeLe: '7 mai', prevueLe: '11 mai', transporteur: 'Heppner', colis: 11, montant: 6870, statut: 'RETARD' },
];

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

const chipBase = 'inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition';
const chipOff = 'border-neutral-200 text-neutral-500 hover:border-neutral-300 dark:border-navy-700 dark:text-neutral-400';
const chipOn = 'border-neutral-900 bg-neutral-900 text-white dark:border-white dark:bg-white dark:text-navy-950';

const ORDER: Statut[] = ['PREPARATION', 'EN_COURS', 'LIVREE', 'RETARD'];

export function LivraisonsBoard() {
  const [filtre, setFiltre] = useState<'ALL' | Statut>('ALL');
  const [q, setQ] = useState('');

  const counts = useMemo(() => {
    const c: Record<Statut, number> = { PREPARATION: 0, EN_COURS: 0, LIVREE: 0, RETARD: 0 };
    for (const l of LIVRAISONS) c[l.statut]++;
    return c;
  }, []);

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    return LIVRAISONS.filter(
      (l) =>
        (filtre === 'ALL' || l.statut === filtre) &&
        (query === '' || l.client.toLowerCase().includes(query) || l.numero.toLowerCase().includes(query)),
    );
  }, [filtre, q]);

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-2xl font-bold">Livraisons &amp; suivi</h1>
        <p className="mt-0.5 text-sm text-neutral-500">
          État des livraisons des commandes — préparation, expédition, réception et retards.
        </p>
      </div>

      {/* KPIs */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiTile label="En préparation" value={String(counts.PREPARATION)} sub="à expédier" />
        <KpiTile label="En cours" value={String(counts.EN_COURS)} sub="en transit" pill={{ text: 'suivi transporteur', tone: 'neutral' }} />
        <KpiTile label="Livrées" value={String(counts.LIVREE)} pill={{ text: 'à jour', tone: 'up' }} />
        <KpiTile label="En retard" value={String(counts.RETARD)} pill={counts.RETARD > 0 ? { text: 'à traiter', tone: 'down' } : { text: 'aucun', tone: 'up' }} />
      </section>

      {/* Recherche + filtres */}
      <div className="flex flex-wrap items-center gap-2">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="N° BL ou client…"
          className="min-w-56 flex-1 rounded-xl border border-neutral-200 bg-white px-3 py-2 text-sm shadow-card outline-none placeholder:text-neutral-400 dark:border-navy-700 dark:bg-navy-950"
        />
        <div className="flex flex-wrap items-center gap-2">
          <button type="button" onClick={() => setFiltre('ALL')} className={`${chipBase} ${filtre === 'ALL' ? chipOn : chipOff}`}>
            Toutes <b className="opacity-60">{LIVRAISONS.length}</b>
          </button>
          {ORDER.map((s) => (
            <button key={s} type="button" onClick={() => setFiltre(s)} className={`${chipBase} ${filtre === s ? chipOn : chipOff}`}>
              {STATUT_LABEL[s]} <b className="opacity-60">{counts[s]}</b>
            </button>
          ))}
        </div>
      </div>

      {/* Tableau */}
      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">N° BL</th>
              <th className="px-4 py-2.5 font-medium">Client</th>
              <th className="px-4 py-2.5 font-medium">Commandé le</th>
              <th className="px-4 py-2.5 font-medium">Livraison prévue</th>
              <th className="px-4 py-2.5 font-medium">Transporteur</th>
              <th className="px-4 py-2.5 text-right font-medium">Colis</th>
              <th className="px-4 py-2.5 text-right font-medium">Montant</th>
              <th className="px-4 py-2.5 font-medium">Statut</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {filtered.map((l) => (
              <tr key={l.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-3 font-mono text-xs font-medium text-brand dark:text-accent">{l.numero}</td>
                <td className="px-4 py-3">
                  <p className="font-medium">{l.client}</p>
                  <p className="text-xs text-neutral-400">{l.ville}</p>
                </td>
                <td className="px-4 py-3 text-neutral-500">{l.commandeLe}</td>
                <td className="px-4 py-3 text-neutral-500">{l.prevueLe}</td>
                <td className="px-4 py-3 text-neutral-500">{l.transporteur}</td>
                <td className="px-4 py-3 text-right tabular-nums text-neutral-500">{l.colis}</td>
                <td className="px-4 py-3 text-right font-medium tabular-nums">{EUR.format(l.montant)}</td>
                <td className="px-4 py-3">
                  <span className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${STATUT_STYLE[l.statut]}`}>
                    {STATUT_LABEL[l.statut]}
                  </span>
                </td>
              </tr>
            ))}
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-10 text-center text-neutral-400">Aucune livraison pour ce filtre.</td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
