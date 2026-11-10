import { listImportLogs, listFichiersDepot, type ImportLog } from '@/lib/api';
import { AdSyncTrigger } from '@/components/ad-sync-trigger';
import { SynchroMinos } from '@/components/admin/synchro-minos';
import { RapportMinos, type LigneRapport } from '@/components/admin/rapport-minos';
import { TYPES_MINOS, formatDuree, formatTaille, typeMinos } from '@/lib/minos';

/** Les imports lancés à moins de 30 min du plus récent forment « la dernière synchro ». */
const FENETRE_LOT_MS = 30 * 60 * 1000;

function dureeSec(l: ImportLog): number | null {
  if (!l.startedAt || !l.finishedAt) return null;
  return Math.max(0, Math.round((new Date(l.finishedAt).getTime() - new Date(l.startedAt).getTime()) / 1000));
}

function Chiffre({ libelle, valeur, alerte = false }: { libelle: string; valeur: string; alerte?: boolean }) {
  return (
    <div className="rounded-xl border border-neutral-100 bg-neutral-50/60 px-4 py-3">
      <p className={`text-xl font-bold tabular-nums ${alerte ? 'text-amber-600' : 'text-neutral-900'}`}>{valeur}</p>
      <p className="mt-0.5 text-xs text-neutral-500">{libelle}</p>
    </div>
  );
}

/** Synchro AD, synchro Minos manuelle (fichiers d'interface) et rapport détaillé des intégrations. */
export async function AdminSynchrosOnglet() {
  const [logs, depot] = await Promise.all([listImportLogs(), listFichiersDepot()]);

  // Poids des fichiers encore présents (le journal ne l'enregistre pas toujours).
  const poidsParNom = new Map((depot?.fichiers ?? []).map((f) => [f.nom, f.taille]));
  const recents = (logs ?? []).slice(0, 50);
  const plusRecent = recents.length ? new Date(recents[0].createdAt).getTime() : 0;

  const lignes: LigneRapport[] = recents.map((l) => {
    const t = typeMinos(l.fileName);
    return {
      id: l.id,
      nom: l.fileName,
      type: t ? TYPES_MINOS[t].label : '—',
      statut: l.status,
      poids: l.fileSizeBytes ?? poidsParNom.get(l.fileName) ?? null,
      lignes: l.rowsTotal,
      integrees: l.rowsOk,
      rejetees: l.rowsFailed,
      dureeSec: dureeSec(l),
      date: l.startedAt ?? l.createdAt,
      erreurs: l.errorMessage,
      dansDernierLot: plusRecent - new Date(l.createdAt).getTime() <= FENETRE_LOT_MS,
    };
  });

  const lot = lignes.filter((l) => l.dansDernierLot);
  const somme = (f: (l: LigneRapport) => number) => lot.reduce((s, l) => s + f(l), 0);
  const poidsLot = lot.reduce((s, l) => s + (l.poids ?? 0), 0);
  const dureeLot = lot.every((l) => l.dureeSec != null) ? somme((l) => l.dureeSec ?? 0) : null;

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
        <h2 className="border-b border-neutral-100 px-5 py-3 text-sm font-semibold">Synchro Minos</h2>
        <SynchroMinos racine={depot?.racine ?? null} fichiers={depot?.fichiers ?? null} />
      </section>

      <section className="rounded-2xl bg-white shadow-card">
        <h2 className="border-b border-neutral-100 px-5 py-3 text-sm font-semibold">Rapport de synchronisation</h2>
        {logs === null ? (
          <p className="px-5 py-6 text-sm text-amber-700">Rapport indisponible — l&apos;API est-elle démarrée ?</p>
        ) : (
          <>
            {lot.length > 0 ? (
              <div className="border-b border-neutral-100 px-5 py-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-neutral-400">
                  Dernière synchro — {lot.length} fichier{lot.length > 1 ? 's' : ''}
                </p>
                <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
                  <Chiffre libelle="Fichiers" valeur={String(lot.length)} />
                  <Chiffre libelle="Poids total" valeur={poidsLot > 0 ? formatTaille(poidsLot) : '—'} />
                  <Chiffre libelle="Lignes lues" valeur={somme((l) => l.lignes).toLocaleString('fr-FR')} />
                  <Chiffre libelle="Intégrées" valeur={somme((l) => l.integrees).toLocaleString('fr-FR')} />
                  <Chiffre
                    libelle="Rejetées"
                    valeur={somme((l) => l.rejetees).toLocaleString('fr-FR')}
                    alerte={somme((l) => l.rejetees) > 0}
                  />
                  <Chiffre libelle="Durée" valeur={formatDuree(dureeLot)} />
                </div>
              </div>
            ) : null}
            <RapportMinos lignes={lignes} />
          </>
        )}
      </section>
    </div>
  );
}
