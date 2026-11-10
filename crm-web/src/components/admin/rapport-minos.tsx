'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Download } from 'lucide-react';
import { formatDuree, formatTaille } from '@/lib/minos';
import { FUSEAU } from '@/lib/planning-dates';

export type LigneRapport = {
  id: string;
  nom: string;
  type: string; // libellé (Clients, Articles…) ou « — »
  statut: 'PENDING' | 'PROCESSING' | 'SUCCESS' | 'FAILED';
  poids: number | null;
  lignes: number;
  integrees: number;
  rejetees: number;
  dureeSec: number | null;
  date: string; // ISO
  erreurs: string | null;
  dansDernierLot: boolean;
};

// Heure affichée À PARIS (fuseau de la plateforme), quel que soit le fuseau du serveur ou du navigateur.
const dateFr = new Intl.DateTimeFormat('fr-FR', { timeZone: FUSEAU, dateStyle: 'short', timeStyle: 'short' });

const STATUT = {
  SUCCESS: { label: 'Réussi', classes: 'bg-emerald-50 text-emerald-700' },
  FAILED: { label: 'En échec', classes: 'bg-red-50 text-red-700' },
  PROCESSING: { label: 'En cours', classes: 'bg-blue-50 text-blue-700' },
  PENDING: { label: 'En attente', classes: 'bg-neutral-100 text-neutral-600' },
} as const;

/** Échappe une cellule CSV (séparateur « ; » pour Excel en français). */
const csv = (v: string | number | null) => `"${String(v ?? '').replace(/"/g, '""').replace(/\r?\n/g, ' | ')}"`;

function telecharger(lignes: LigneRapport[]) {
  const entete = ['Date', 'Fichier', 'Type', 'Statut', 'Poids (octets)', 'Lignes lues', 'Intégrées', 'Rejetées', 'Durée (s)', 'Erreurs'];
  const corps = lignes.map((l) =>
    [l.date, l.nom, l.type, STATUT[l.statut].label, l.poids, l.lignes, l.integrees, l.rejetees, l.dureeSec, l.erreurs]
      .map((v) => csv(v as string | number | null))
      .join(';'),
  );
  // BOM UTF-8 pour que les accents s'affichent correctement dans Excel.
  const blob = new Blob(['﻿' + [entete.map(csv).join(';'), ...corps].join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `rapport-synchro-minos-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

/**
 * Un import resté « en attente » ou « en cours » plus longtemps que cela est considéré comme interrompu (API
 * redémarrée en plein import) : l'API ne remet jamais ces statuts à zéro, il ne faut pas rafraîchir la page sans fin.
 */
const ABANDON_IMPORT_MS = 60 * 60 * 1000;
/** Plafond de rafraîchissements automatiques d'une même visite (3 s chacun, soit 5 minutes). */
const RAFRAICHISSEMENTS_MAX = 100;

/** Rapport détaillé des intégrations. Se rafraîchit seul tant qu'un import récent est en attente ou en cours (borné). */
export function RapportMinos({ lignes }: { lignes: LigneRapport[] }) {
  const router = useRouter();
  const enCours = lignes.some(
    (l) =>
      (l.statut === 'PENDING' || l.statut === 'PROCESSING') &&
      Date.now() - new Date(l.date).getTime() < ABANDON_IMPORT_MS,
  );

  useEffect(() => {
    if (!enCours) return;
    let n = 0;
    const t = setInterval(() => {
      // Chaque rafraîchissement refait tout le rendu de /admin et s'empile derrière une action en cours (synchro AD) :
      // on le borne pour ne jamais retenir l'écran indéfiniment.
      if (++n > RAFRAICHISSEMENTS_MAX) clearInterval(t);
      else router.refresh();
    }, 3000);
    return () => clearInterval(t);
  }, [enCours, router]);

  if (lignes.length === 0) {
    return <p className="px-5 py-8 text-center text-sm text-neutral-400">Aucune intégration enregistrée.</p>;
  }

  return (
    <div>
      <div className="flex items-center justify-between gap-3 px-5 py-2.5 text-xs text-neutral-500">
        <span>
          {enCours ? 'Traitement en cours — mise à jour automatique…' : `${lignes.length} dernière${lignes.length > 1 ? 's' : ''} intégration${lignes.length > 1 ? 's' : ''}`}
        </span>
        <button
          type="button"
          onClick={() => telecharger(lignes)}
          className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-300 px-2.5 py-1.5 font-medium text-neutral-700 transition hover:bg-neutral-50"
        >
          <Download size={13} aria-hidden /> Exporter (CSV)
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500">
            <tr>
              <th className="px-5 py-2.5 font-medium">Date</th>
              <th className="px-3 py-2.5 font-medium">Fichier</th>
              <th className="px-3 py-2.5 font-medium">Statut</th>
              <th className="px-3 py-2.5 text-right font-medium">Poids</th>
              <th className="px-3 py-2.5 text-right font-medium">Lignes lues</th>
              <th className="px-3 py-2.5 text-right font-medium">Intégrées</th>
              <th className="px-3 py-2.5 text-right font-medium">Rejetées</th>
              <th className="px-5 py-2.5 text-right font-medium">Durée</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100">
            {lignes.map((l) => (
              <tr key={l.id} className={`align-top hover:bg-neutral-50 ${l.dansDernierLot ? 'bg-brand/5' : ''}`}>
                <td className="whitespace-nowrap px-5 py-2.5 text-neutral-600">{dateFr.format(new Date(l.date))}</td>
                <td className="px-3 py-2.5">
                  <p className="font-mono text-xs">{l.nom}</p>
                  <p className="text-xs text-neutral-400">{l.type}</p>
                  {l.erreurs ? (
                    <details className="mt-1">
                      <summary className="cursor-pointer text-xs font-medium text-red-600">Voir les erreurs</summary>
                      <pre className="mt-1 max-h-40 max-w-xl overflow-auto whitespace-pre-wrap rounded-lg bg-red-50 p-2 text-xs text-red-700">
                        {l.erreurs}
                      </pre>
                    </details>
                  ) : null}
                </td>
                <td className="px-3 py-2.5">
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUT[l.statut].classes}`}>
                    {STATUT[l.statut].label}
                  </span>
                </td>
                <td className="px-3 py-2.5 text-right tabular-nums">{formatTaille(l.poids)}</td>
                <td className="px-3 py-2.5 text-right tabular-nums">{l.lignes.toLocaleString('fr-FR')}</td>
                <td className="px-3 py-2.5 text-right tabular-nums">{l.integrees.toLocaleString('fr-FR')}</td>
                <td
                  className={`px-3 py-2.5 text-right tabular-nums ${l.rejetees > 0 ? 'font-semibold text-amber-700' : 'text-neutral-400'}`}
                >
                  {l.rejetees.toLocaleString('fr-FR')}
                </td>
                <td className="px-5 py-2.5 text-right tabular-nums text-neutral-500">{formatDuree(l.dureeSec)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
