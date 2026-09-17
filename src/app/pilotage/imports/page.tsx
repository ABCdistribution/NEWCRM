import { getMe, listImportLogs, listFichiersDepot, type ImportLog } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { ImportTrigger } from '@/components/import-trigger';

export const metadata = { title: 'Imports Minos — Helios' };

const STATUS_STYLES: Record<ImportLog['status'], string> = {
  PENDING: 'bg-neutral-400/15 text-neutral-500',
  PROCESSING: 'bg-amber-500/15 text-amber-700 dark:text-amber-400',
  SUCCESS: 'bg-green-600/10 text-green-700 dark:text-green-400',
  FAILED: 'bg-red-500/15 text-red-600 dark:text-red-400',
};

const STATUS_LABELS: Record<ImportLog['status'], string> = {
  PENDING: 'En file',
  PROCESSING: 'En cours',
  SUCCESS: 'Réussi',
  FAILED: 'Échec',
};

const DT_FMT = new Intl.DateTimeFormat('fr-FR', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

function fmt(date: string | null): string {
  return date ? DT_FMT.format(new Date(date)) : '—';
}

export default async function ImportsPage() {
  const me = await getMe();
  if (me?.role !== 'ADMIN') return <AccesRefuse />;

  const [logs, depot] = await Promise.all([listImportLogs(), listFichiersDepot()]);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold">Imports Minos</h1>
        <p className="text-sm text-neutral-500">
          Synchronisation du référentiel (clients, commandes…) depuis les exports Minos. Le fichier
          doit être accessible sur le serveur de l&apos;API.
        </p>
      </div>

      <ImportTrigger depot={depot} />

      <div>
        <h2 className="mb-2 text-sm font-semibold text-neutral-500">Journal des imports</h2>
        {logs === null ? (
          <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            Journal indisponible — l&apos;API est-elle démarrée ?
          </p>
        ) : logs.length === 0 ? (
          <p className="rounded-xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
            Aucun import lancé pour le moment.
          </p>
        ) : (
          <div className="overflow-x-auto rounded-xl bg-white shadow-card">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
                <tr>
                  <th className="px-3 py-2.5 font-medium">Fichier</th>
                  <th className="px-3 py-2.5 font-medium">Source</th>
                  <th className="px-3 py-2.5 font-medium">Statut</th>
                  <th className="px-3 py-2.5 text-right font-medium">Lignes (OK / échec / total)</th>
                  <th className="px-3 py-2.5 font-medium">Démarré</th>
                  <th className="px-3 py-2.5 font-medium">Terminé</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                {logs.map((log) => (
                  <tr key={log.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                    <td className="px-3 py-2.5">
                      <p className="font-mono text-xs">{log.fileName}</p>
                      {log.errorMessage ? (
                        <p className="mt-0.5 max-w-md truncate text-xs text-red-500" title={log.errorMessage}>
                          {log.errorMessage}
                        </p>
                      ) : null}
                    </td>
                    <td className="px-3 py-2.5 text-neutral-500">{log.source}</td>
                    <td className="px-3 py-2.5">
                      <span
                        className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[log.status]}`}
                      >
                        {STATUS_LABELS[log.status]}
                      </span>
                    </td>
                    <td className="px-3 py-2.5 text-right font-mono text-xs">
                      <span className="text-green-600 dark:text-green-400">{log.rowsOk}</span>
                      {' / '}
                      <span className={log.rowsFailed > 0 ? 'text-red-500' : 'text-neutral-400'}>
                        {log.rowsFailed}
                      </span>
                      {' / '}
                      <span className="text-neutral-500">{log.rowsTotal}</span>
                    </td>
                    <td className="px-3 py-2.5 text-xs text-neutral-500">{fmt(log.startedAt)}</td>
                    <td className="px-3 py-2.5 text-xs text-neutral-500">{fmt(log.finishedAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
