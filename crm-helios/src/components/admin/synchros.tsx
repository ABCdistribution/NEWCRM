import { listImportLogs, type ImportLog } from '@/lib/api';
import { AdSyncTrigger } from '@/components/ad-sync-trigger';

const dateFr = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short' });

const STATUT: Record<ImportLog['status'], { label: string; classes: string }> = {
  SUCCESS: { label: 'Réussi', classes: 'bg-emerald-50 text-emerald-700' },
  FAILED: { label: 'En échec', classes: 'bg-red-50 text-red-700' },
  PROCESSING: { label: 'En cours', classes: 'bg-blue-50 text-blue-700' },
  PENDING: { label: 'En attente', classes: 'bg-neutral-100 text-neutral-600' },
};

function duree(log: ImportLog): string {
  if (!log.startedAt || !log.finishedAt) return '—';
  const s = Math.max(0, Math.round((new Date(log.finishedAt).getTime() - new Date(log.startedAt).getTime()) / 1000));
  return s < 60 ? `${s} s` : `${Math.floor(s / 60)} min ${String(s % 60).padStart(2, '0')} s`;
}

/** Synchro AD (lancement manuel) et historique des imports ERP (journal `minos_import_logs`). */
export async function AdminSynchrosOnglet() {
  const logs = await listImportLogs();

  return (
    <div className="flex flex-col gap-5">
      <section className="rounded-2xl bg-white shadow-card">
        <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
          <div>
            <h2 className="text-sm font-semibold">Active Directory</h2>
            <p className="mt-0.5 text-sm text-neutral-500">
              Importe la force de vente française : comptes, secteurs, régions, directeurs et photos.
            </p>
          </div>
          <AdSyncTrigger />
        </div>
      </section>

      <section className="rounded-2xl bg-white shadow-card">
        <h2 className="border-b border-neutral-100 px-5 py-3 text-sm font-semibold">Historique des imports ERP</h2>
        {logs === null ? (
          <p className="px-5 py-6 text-sm text-amber-700">Historique indisponible — l&apos;API est-elle démarrée ?</p>
        ) : logs.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-neutral-400">Aucun import enregistré.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Date</th>
                  <th className="px-3 py-2.5 font-medium">Fichier</th>
                  <th className="px-3 py-2.5 font-medium">Source</th>
                  <th className="px-3 py-2.5 font-medium">Statut</th>
                  <th className="px-3 py-2.5 text-right font-medium">Lignes</th>
                  <th className="px-3 py-2.5 text-right font-medium">Rejets</th>
                  <th className="px-3 py-2.5 text-right font-medium">Durée</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {logs.slice(0, 50).map((l) => (
                  <tr key={l.id} className="align-top hover:bg-neutral-50">
                    <td className="whitespace-nowrap px-4 py-2.5 text-neutral-600">
                      {dateFr.format(new Date(l.startedAt ?? l.createdAt))}
                    </td>
                    <td className="px-3 py-2.5">
                      <p className="font-mono text-xs">{l.fileName}</p>
                      {l.errorMessage ? <p className="mt-0.5 max-w-md text-xs text-red-600">{l.errorMessage}</p> : null}
                    </td>
                    <td className="px-3 py-2.5 text-neutral-500">{l.source}</td>
                    <td className="px-3 py-2.5">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUT[l.status].classes}`}>
                        {STATUT[l.status].label}
                      </span>
                    </td>
                    <td className="px-3 py-2.5 text-right tabular-nums">
                      {l.rowsOk}/{l.rowsTotal}
                    </td>
                    <td
                      className={`px-3 py-2.5 text-right tabular-nums ${l.rowsFailed > 0 ? 'font-semibold text-amber-700' : 'text-neutral-400'}`}
                    >
                      {l.rowsFailed}
                    </td>
                    <td className="px-3 py-2.5 text-right tabular-nums text-neutral-500">{duree(l)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
