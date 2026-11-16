'use client';

import { useEffect, useRef, useState } from 'react';
import { Ban, Check, Download, History, X } from 'lucide-react';
import { chargerPassesInactifs, type ReponsePassesInactifs } from '@/lib/clients-inactifs-actions';
import {
  dateHeure,
  envoiAdv,
  jourLong,
  moisCourant,
  moisValide,
  nomFichierCsv,
  versCsv,
  type ClientPasseInactif,
} from '@/lib/clients-inactifs';

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const TH = 'px-3 py-2.5 text-left text-xs font-semibold text-neutral-700';

/**
 * Bouton « Clients passés inactifs » de la page /clients et son modal : choix du mois, nombre de clients, export CSV et
 * tableau (enseigne avec « Retiré de l'AS400 », code, ville, date, auteur du passage, DR, envoi à l'ADV).
 * Les données viennent de `chargerPassesInactifs` (Server Action → API, bornée par rôle et périmètre). Tant que l'API
 * n'enregistre pas l'historique, le modal l'annonce : aucune liste vide trompeuse.
 * `ouvertInitial`, `moisInitial`, `reponseInitiale` : états d'ouverture pour les tests de rendu.
 */
export function ClientsInactifs({
  ouvertInitial = false,
  moisInitial,
  reponseInitiale = null,
}: {
  ouvertInitial?: boolean;
  moisInitial?: string;
  reponseInitiale?: ReponsePassesInactifs | null;
}) {
  const [ouvert, setOuvert] = useState(ouvertInitial);
  const [mois, setMois] = useState(moisInitial ?? moisCourant());
  const [reponse, setReponse] = useState<ReponsePassesInactifs | null>(reponseInitiale);
  const [attente, setAttente] = useState(false);
  const declencheur = useRef<HTMLButtonElement>(null);
  const fermer = useRef<HTMLButtonElement>(null);
  const sequence = useRef(0);

  // Chargement à l'ouverture et à chaque changement de mois ; une réponse arrivée après un autre choix est ignorée.
  useEffect(() => {
    if (!ouvert || !moisValide(mois)) return;
    const n = ++sequence.current;
    setAttente(true);
    chargerPassesInactifs(mois).then((r) => {
      if (n !== sequence.current) return;
      setReponse(r);
      setAttente(false);
    });
  }, [ouvert, mois]);

  // Échap ferme ; le fond de page ne défile pas tant que le modal est ouvert ; le focus va sur « Fermer » puis revient.
  useEffect(() => {
    if (!ouvert) return;
    const surTouche = (e: KeyboardEvent) => e.key === 'Escape' && setOuvert(false);
    document.addEventListener('keydown', surTouche);
    document.body.style.overflow = 'hidden';
    fermer.current?.focus();
    const retour = declencheur.current;
    return () => {
      document.removeEventListener('keydown', surTouche);
      document.body.style.overflow = '';
      retour?.focus();
    };
  }, [ouvert]);

  const lignes: ClientPasseInactif[] = reponse?.data?.lignes ?? [];

  const exporter = () => {
    const blob = new Blob([versCsv(lignes)], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = nomFichierCsv(mois);
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <>
      <button
        ref={declencheur}
        type="button"
        onClick={() => setOuvert(true)}
        className={`inline-flex h-10 items-center gap-2 rounded-xl border border-neutral-300 bg-white px-4 text-sm font-semibold text-neutral-600 transition hover:bg-neutral-50 ${FOCUS}`}
      >
        <History size={16} aria-hidden />
        Clients passés inactifs
      </button>

      {ouvert ? (
        <div
          className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/50 p-4 sm:p-8"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setOuvert(false);
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="inactifs-titre"
            className="w-full max-w-6xl overflow-hidden rounded-2xl bg-white shadow-xl"
          >
            <div className="flex items-center justify-between bg-navy px-6 py-4 text-white">
              <h2 id="inactifs-titre" className="flex items-center gap-2.5 text-lg font-semibold">
                <Ban size={18} aria-hidden />
                Clients passés inactifs
              </h2>
              <button
                ref={fermer}
                type="button"
                onClick={() => setOuvert(false)}
                aria-label="Fermer"
                className="rounded-lg p-1.5 text-white transition hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
              >
                <X size={20} aria-hidden />
              </button>
            </div>

            <div className="p-6">
              <div className="flex flex-wrap items-center gap-x-4 gap-y-3">
                <label className="flex items-center gap-2 text-sm text-neutral-600">
                  Mois :
                  <input
                    type="month"
                    value={mois}
                    max={moisCourant()}
                    onChange={(e) => moisValide(e.target.value) && setMois(e.target.value)}
                    className={`h-10 rounded-lg border border-neutral-300 bg-white px-3 text-sm text-neutral-800 ${FOCUS}`}
                  />
                </label>
                {reponse?.data ? (
                  <span className="text-sm text-neutral-500" aria-live="polite">
                    {lignes.length} client(s)
                  </span>
                ) : null}
                <button
                  type="button"
                  onClick={exporter}
                  disabled={lignes.length === 0}
                  className={`ml-auto inline-flex h-10 items-center gap-2 rounded-lg bg-brand px-4 text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`}
                >
                  <Download size={15} aria-hidden />
                  Exporter CSV
                </button>
              </div>

              <div className="mt-5" aria-busy={attente}>
                {reponse?.erreur !== undefined ? (
                  <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
                    {reponse.erreur}
                  </p>
                ) : reponse?.indisponible ? (
                  <p role="status" className="px-4 py-10 text-center text-sm text-neutral-500">
                    L&apos;historique des passages en inactif n&apos;est pas encore enregistré par le CRM.
                  </p>
                ) : reponse?.data === undefined ? (
                  <p role="status" className="px-4 py-10 text-center text-sm text-neutral-500">
                    Chargement…
                  </p>
                ) : lignes.length === 0 ? (
                  <p role="status" className="px-4 py-10 text-center text-sm text-neutral-500">
                    Aucun client passé inactif sur ce mois.
                  </p>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[56rem] text-sm">
                      <thead>
                        <tr className="border-y border-neutral-200">
                          <th scope="col" className={TH}>Enseigne</th>
                          <th scope="col" className={TH}>Code</th>
                          <th scope="col" className={TH}>Ville</th>
                          <th scope="col" className={TH}>Date</th>
                          <th scope="col" className={TH}>Modifié par</th>
                          <th scope="col" className={TH}>DR</th>
                          <th scope="col" className={TH}>Envoyé à l&apos;ADV</th>
                        </tr>
                      </thead>
                      <tbody>
                        {lignes.map((l) => {
                          const envoi = envoiAdv(l);
                          return (
                            <tr key={`${l.id}-${l.date}`} className="border-b border-neutral-100 last:border-0">
                              <td className="px-3 py-2.5">
                                {l.enseigne}
                                {l.retireAs400 ? (
                                  <span className="ml-2 rounded-md bg-neutral-100 px-1.5 py-0.5 text-[11px] font-semibold text-neutral-600">
                                    Retiré de l&apos;AS400
                                  </span>
                                ) : null}
                              </td>
                              <td className="px-3 py-2.5 font-mono text-xs text-neutral-600">{l.codeAs400}</td>
                              <td className="px-3 py-2.5 text-neutral-700">{l.ville ?? ''}</td>
                              <td className="whitespace-nowrap px-3 py-2.5 tabular-nums text-neutral-700">{dateHeure(l.date)}</td>
                              <td className="px-3 py-2.5 text-neutral-700">{l.modifiePar ?? ''}</td>
                              <td className="px-3 py-2.5 text-neutral-700">{l.dr ?? ''}</td>
                              <td className="px-3 py-2.5">
                                {envoi.envoye ? (
                                  <span className="inline-flex items-center gap-1.5 tabular-nums text-neutral-700">
                                    <Check size={15} className="text-emerald-600" aria-hidden />
                                    {envoi.texte}
                                  </span>
                                ) : (
                                  <span className="text-neutral-500">{envoi.texte}</span>
                                )}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              {reponse?.data?.depuis ? (
                <p className="mt-4 text-xs text-neutral-500">
                  Seuls les passages en inactif effectués depuis le CRM à partir du {jourLong(reponse.data.depuis)} sont recensés.
                </p>
              ) : null}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
