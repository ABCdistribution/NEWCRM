'use client';

import { useState, useTransition } from 'react';
import { CalendarPlus2, Check, Copy, Download, X } from 'lucide-react';
import { getIcalInfo } from '@/lib/tournee-actions';

/**
 * Synchronisation Outlook : fournit l'URL personnelle du flux ICS du planning
 * d'activité — Outlook s'y abonne et les visites / RDV apparaissent dans le
 * calendrier, mis à jour automatiquement.
 */
export function OutlookSyncButton() {
  const [ouvert, setOuvert] = useState(false);
  const [url, setUrl] = useState<string | null>(null);
  const [erreur, setErreur] = useState(false);
  const [copie, setCopie] = useState(false);
  const [pending, startTransition] = useTransition();

  const ouvrir = () => {
    setOuvert(true);
    if (url) return;
    startTransition(async () => {
      const info = await getIcalInfo();
      if (!info) setErreur(true);
      else {
        // L'API est servie sur le même hôte que Helios, port 4000.
        setUrl(`${window.location.protocol}//${window.location.hostname}:4000/tournees/ical/${info.userId}/${info.token}`);
      }
    });
  };

  const copier = async () => {
    if (!url) return;
    try {
      await navigator.clipboard.writeText(url);
      setCopie(true);
      window.setTimeout(() => setCopie(false), 2000);
    } catch {
      // presse-papier indisponible — l'utilisateur peut sélectionner le champ
    }
  };

  return (
    <>
      <button
        type="button"
        onClick={ouvrir}
        className="inline-flex items-center gap-1.5 rounded-xl border border-neutral-200 bg-white px-3 py-1.5 text-xs font-semibold text-neutral-600 shadow-sm transition hover:border-brand hover:text-brand dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-300 dark:hover:border-accent dark:hover:text-accent"
      >
        <CalendarPlus2 size={14} /> Synchroniser avec Outlook
      </button>

      {ouvert ? (
        <div className="fixed inset-0 z-[60] flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-24" onClick={() => setOuvert(false)}>
          <div className="w-full max-w-lg rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between border-b border-neutral-100 px-5 py-3.5 dark:border-navy-700">
              <h2 className="text-sm font-bold">Synchroniser mon planning avec Outlook</h2>
              <button type="button" onClick={() => setOuvert(false)} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
                <X size={17} />
              </button>
            </div>

            <div className="flex flex-col gap-4 px-5 py-4">
              {erreur ? (
                <p className="text-sm text-red-500">Impossible de générer votre lien — l&apos;API est-elle démarrée ?</p>
              ) : !url ? (
                <p className="py-4 text-center text-sm text-neutral-400">{pending ? 'Génération du lien…' : '…'}</p>
              ) : (
                <>
                  <p className="text-sm text-neutral-500">
                    Abonnez Outlook à ce lien personnel : vos visites et rendez-vous du planning
                    d&apos;activité apparaîtront dans votre calendrier et se mettront à jour automatiquement.
                  </p>
                  <div className="flex items-center gap-2">
                    <input
                      readOnly
                      value={url}
                      onFocus={(e) => e.target.select()}
                      className="min-w-0 flex-1 rounded-lg border border-neutral-200 bg-neutral-50 px-2.5 py-1.5 font-mono text-[11px] outline-none dark:border-navy-700 dark:bg-navy-950"
                    />
                    <button
                      type="button"
                      onClick={copier}
                      className="inline-flex shrink-0 items-center gap-1.5 rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
                    >
                      {copie ? <Check size={13} /> : <Copy size={13} />} {copie ? 'Copié !' : 'Copier'}
                    </button>
                  </div>

                  <ol className="list-decimal space-y-1 pl-5 text-sm text-neutral-500">
                    <li>Dans Outlook : <span className="font-medium">Calendrier → Ajouter un calendrier → S&apos;abonner à partir du web</span>.</li>
                    <li>Collez le lien ci-dessus, nommez-le « Planning CRM », validez.</li>
                    <li>Outlook actualise le calendrier régulièrement — rien d&apos;autre à faire.</li>
                  </ol>

                  <a
                    href={url}
                    className="inline-flex w-fit items-center gap-1.5 text-xs font-medium text-brand hover:underline dark:text-accent"
                  >
                    <Download size={13} /> Ou télécharger une copie ponctuelle (.ics)
                  </a>
                </>
              )}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
