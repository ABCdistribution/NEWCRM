'use client';

import { useActionState, useState } from 'react';
import { CheckCircle2, FileText, Play, TriangleAlert, XCircle } from 'lucide-react';
import { lancerSynchroMinos, type SynchroMinosState } from '@/lib/admin-actions';
import { TYPES_MINOS, formatTaille, typeMinos } from '@/lib/minos';
import type { FichierDepot } from '@/lib/api';

const INITIAL: SynchroMinosState = { lance: false, error: null, fichiers: [] };
const dateFr = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short' });

/**
 * Synchro Minos manuelle : liste les fichiers d'interface déposés dans la zone d'échange et lance leur intégration.
 * Le traitement est asynchrone : le détail (lignes, rejets, durée) arrive dans le rapport ci-dessous.
 */
export function SynchroMinos({ racine, fichiers }: { racine: string | null; fichiers: FichierDepot[] | null }) {
  const [etat, action, enCours] = useActionState(lancerSynchroMinos, INITIAL);
  const [confirmer, setConfirmer] = useState(false);

  if (fichiers === null) {
    return (
      <p className="px-5 py-5 text-sm text-amber-700">
        Zone d&apos;échange inaccessible — l&apos;API est-elle démarrée ?
      </p>
    );
  }

  const reconnus = fichiers.filter((f) => typeMinos(f.nom) !== null);
  const ignores = fichiers.filter((f) => typeMinos(f.nom) === null);
  const poidsTotal = reconnus.reduce((somme, f) => somme + f.taille, 0);

  return (
    <div className="flex flex-col">
      <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-4">
        <div>
          <p className="text-sm text-neutral-600">
            Intègre les fichiers d&apos;interface Minos déposés dans la zone d&apos;échange : clients, puis articles, puis
            arborescence d&apos;achat.
          </p>
          <p className="mt-1 text-xs text-neutral-400">
            Zone : <span className="font-mono">{racine ?? '—'}</span> · {reconnus.length} fichier
            {reconnus.length > 1 ? 's' : ''} à intégrer · {formatTaille(poidsTotal)}
          </p>
        </div>

        <form action={action} className="flex items-center gap-2">
          {reconnus.map((f) => (
            <input key={f.chemin} type="hidden" name="chemin" value={f.chemin} />
          ))}
          {confirmer && !enCours ? (
            <>
              <span className="text-sm text-neutral-600">
                Intégrer {reconnus.length} fichier{reconnus.length > 1 ? 's' : ''} ({formatTaille(poidsTotal)}) ?
              </span>
              <button
                type="submit"
                onClick={() => setConfirmer(false)}
                className="rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90"
              >
                Confirmer
              </button>
              <button
                type="button"
                onClick={() => setConfirmer(false)}
                className="rounded-xl border border-neutral-300 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50"
              >
                Annuler
              </button>
            </>
          ) : (
            <button
              type="button"
              disabled={reconnus.length === 0 || enCours}
              onClick={() => setConfirmer(true)}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3.5 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Play size={14} aria-hidden />
              {enCours ? 'Lancement…' : 'Lancer la synchro Minos'}
            </button>
          )}
        </form>
      </div>

      {fichiers.length === 0 ? (
        <p className="border-t border-neutral-100 px-5 py-6 text-center text-sm text-neutral-400">
          Aucun fichier dans la zone d&apos;échange pour le moment.
        </p>
      ) : (
        <div className="overflow-x-auto border-t border-neutral-100">
          <table className="w-full text-sm">
            <thead className="bg-neutral-50 text-left text-neutral-500">
              <tr>
                <th className="px-5 py-2 font-medium">Fichier</th>
                <th className="px-3 py-2 font-medium">Type</th>
                <th className="px-3 py-2 text-right font-medium">Poids</th>
                <th className="px-5 py-2 text-right font-medium">Déposé le</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {[...reconnus, ...ignores].map((f) => {
                const t = typeMinos(f.nom);
                return (
                  <tr key={f.chemin} className={t ? '' : 'text-neutral-400'}>
                    <td className="px-5 py-2">
                      <span className="inline-flex items-center gap-2 font-mono text-xs">
                        <FileText size={14} aria-hidden />
                        {f.nom}
                      </span>
                    </td>
                    <td className="px-3 py-2">
                      {t ? TYPES_MINOS[t].label : <span className="text-xs italic">non reconnu — ignoré</span>}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatTaille(f.taille)}</td>
                    <td className="whitespace-nowrap px-5 py-2 text-right text-neutral-500">
                      {dateFr.format(new Date(f.modifieLe))}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {etat.error ? (
        <p className="flex items-center gap-2 border-t border-neutral-100 px-5 py-3 text-sm text-red-600" role="alert">
          <XCircle size={15} aria-hidden /> {etat.error}
        </p>
      ) : null}
      {etat.lance ? (
        <ul className="border-t border-neutral-100 px-5 py-3 text-sm" aria-live="polite">
          {etat.fichiers.map((f) => (
            <li key={f.nom} className="flex items-start gap-2 py-0.5">
              {f.ok ? (
                <CheckCircle2 size={15} className="mt-0.5 shrink-0 text-emerald-600" aria-hidden />
              ) : (
                <TriangleAlert size={15} className="mt-0.5 shrink-0 text-red-600" aria-hidden />
              )}
              <span>
                <span className="font-mono text-xs">{f.nom}</span> —{' '}
                {f.ok ? 'mis en file de traitement' : <span className="text-red-600">{f.message}</span>}
              </span>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
