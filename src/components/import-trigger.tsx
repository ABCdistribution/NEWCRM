'use client';

import { useActionState, useEffect, useState } from 'react';
import { FileText, Play, RefreshCw } from 'lucide-react';
import { triggerImportClients, type ImportState } from '@/lib/admin-actions';
import type { FichierDepot } from '@/lib/api';

const INITIAL: ImportState = { error: null, ok: false };
const KO = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });
const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

/**
 * Déclenchement manuel d'un import Minos : la zone de dépôt AS400 (montée sur le
 * serveur API) est listée — un clic sur un fichier préremplit le chemin.
 */
export function ImportTrigger({
  depot,
}: {
  depot: { racine: string; fichiers: FichierDepot[] } | null;
}) {
  const [state, action, pending] = useActionState(triggerImportClients, INITIAL);
  const [filePath, setFilePath] = useState('');
  const [type, setType] = useState<'clients' | 'articles' | 'centrales'>('clients');

  /** CLI_* → clients, ART_* → articles (modifiable à la main). */
  const choisir = (chemin: string) => {
    setFilePath(chemin);
    const nom = chemin.split('/').pop() ?? '';
    if (nom.toUpperCase().startsWith('ART')) setType('articles');
    else if (nom.toUpperCase().startsWith('ARB')) setType('centrales');
    else if (nom.toUpperCase().startsWith('CLI')) setType('clients');
  };

  useEffect(() => {
    if (state.ok) setFilePath('');
  }, [state.ok]);

  return (
    <div className="flex flex-col gap-3">
      {/* Zone de dépôt */}
      <div className="rounded-2xl bg-white shadow-card">
        <h2 className="flex items-center gap-2 border-b border-neutral-100 px-4 py-2.5 text-sm font-semibold dark:border-navy-700">
          <RefreshCw size={14} className="text-brand dark:text-accent" />
          Zone de dépôt AS400
          <span className="font-mono text-[11px] font-normal text-neutral-400">{depot?.racine ?? '/imports'}</span>
        </h2>
        {depot === null ? (
          <p className="px-4 py-4 text-sm text-amber-700 dark:text-amber-400">
            Zone indisponible — l&apos;API est-elle démarrée ?
          </p>
        ) : depot.fichiers.length === 0 ? (
          <p className="px-4 py-5 text-sm text-neutral-400">
            Aucun fichier déposé. Le montage vers le serveur AS400 (10.3) doit pointer sur{' '}
            <code className="font-mono text-xs">/var/www/imports/as400</code> — les fichiers apparaîtront ici.
          </p>
        ) : (
          <ul className="max-h-56 divide-y divide-neutral-100 overflow-y-auto dark:divide-navy-700">
            {depot.fichiers.map((f) => (
              <li key={f.chemin}>
                <button
                  type="button"
                  onClick={() => choisir(f.chemin)}
                  className={`flex w-full items-center gap-2.5 px-4 py-2 text-left transition hover:bg-neutral-50 dark:hover:bg-navy-800/50 ${
                    filePath === f.chemin ? 'bg-brand/5 dark:bg-accent/10' : ''
                  }`}
                  title="Utiliser ce fichier"
                >
                  <FileText size={14} className="shrink-0 text-neutral-400" />
                  <span className="min-w-0 flex-1 truncate font-mono text-xs">{f.nom}</span>
                  <span className="shrink-0 text-[11px] text-neutral-400">{KO.format(f.taille / 1024)} Ko</span>
                  <span className="shrink-0 text-[11px] text-neutral-400">{DT.format(new Date(f.modifieLe))}</span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Lancement */}
      <form action={action} className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card">
        <input
          name="filePath"
          value={filePath}
          onChange={(e) => choisir(e.target.value)}
          placeholder="Chemin du fichier (clic sur un fichier ci-dessus)…"
          className="min-w-64 flex-1 rounded-lg border border-neutral-200 bg-white px-3 py-2 font-mono text-xs outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
        />
        <select
          name="type"
          value={type}
          onChange={(e) => setType(e.target.value as 'clients' | 'articles' | 'centrales')}
          className="rounded-lg border border-neutral-200 bg-white px-2.5 py-2 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
          aria-label="Type d'import"
        >
          <option value="clients">Clients (CLI)</option>
          <option value="articles">Articles (ART)</option>
          <option value="centrales">Arborescence (ARB)</option>
        </select>
        <button
          type="submit"
          disabled={pending || !filePath}
          className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
        >
          <Play size={14} />
          {pending ? 'Lancement…' : 'Importer'}
        </button>
        {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
        {state.ok ? <p className="w-full text-xs text-emerald-500">Import mis en file d&apos;attente ✅</p> : null}
      </form>
    </div>
  );
}
