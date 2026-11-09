// Contenus des onglets des fiches « chef de secteur » et « promoteur » (composants serveur, lecture seule).
import Link from 'next/link';
import { CheckCircle2, Circle, Sprout, Store, Briefcase } from 'lucide-react';
import { ClassBadge } from './class-badge';
import { CARTE, FOCUS, Pastille } from './equipe-ui';
import type { CommandeRow, PlanningItem, RapportDetail, TourneeEtapeRow, VisiteActivite } from '@/lib/api';
import { ajouterJours, heureDe, iso, resumeEcarts, calculerEcarts, LIBELLE_STATUT_RAPPORT } from '@/lib/equipe-utils';
import { FUSEAU } from '@/lib/planning-dates';

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const JOUR_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });
const DATE_HEURE = new Intl.DateTimeFormat('fr-FR', { timeZone: FUSEAU, day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
const EUR2 = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' });

type LigneJour = { id: string; titre: string; ville: string | null; classe: string | null; genre: 'client' | 'prospect' | 'adm' | 'libre'; heure: string | null; fait: boolean; note?: string | null };

function ligneDepuisEtape(e: TourneeEtapeRow): LigneJour {
  const heure = heureDe(e.datePassage);
  if (e.adm) return { id: e.id, titre: 'ADM', ville: null, classe: null, genre: 'adm', heure, fait: e.fait, note: e.note };
  if (e.client) return { id: e.id, titre: e.client.enseigne, ville: e.client.ville, classe: e.client.niveauClass, genre: 'client', heure, fait: e.fait, note: e.note };
  if (e.prospect) return { id: e.id, titre: e.prospect.enseigne, ville: e.prospect.ville, classe: e.prospect.niveauClass, genre: 'prospect', heure, fait: e.fait, note: e.note };
  return { id: e.id, titre: e.libelle ?? '—', ville: null, classe: null, genre: 'libre', heure, fait: e.fait, note: e.note };
}

function ligneDepuisVisite(v: PlanningItem): LigneJour {
  return { id: v.id, titre: v.client.enseigne, ville: v.client.ville, classe: v.client.niveauClass, genre: 'client', heure: heureDe(v.datePassage), fait: v.fait };
}

/** Grille « un bloc par jour » d'une semaine (lecture seule) ; le samedi n'apparaît que s'il porte des lignes. */
function GrilleSemaine({ lundi, lignesDuJour }: { lundi: Date; lignesDuJour: (dateIso: string) => LigneJour[] }) {
  const jours = JOURS.map((nom, i) => {
    const d = ajouterJours(lundi, i);
    return { nom, d, date: iso(d), lignes: lignesDuJour(iso(d)).sort((a, b) => (a.heure ?? '99').localeCompare(b.heure ?? '99')) };
  }).filter((j, i) => i < 5 || j.lignes.length > 0);
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
      {jours.map((j) => (
        <section key={j.date} className={`flex flex-col ${CARTE}`} aria-label={`${j.nom} ${JOUR_FMT.format(j.d)}`}>
          <header className="flex items-baseline justify-between border-b border-neutral-100 px-3.5 py-2.5 dark:border-navy-700">
            <span className="text-sm font-semibold">{j.nom}</span>
            <span className="text-xs text-neutral-400">{JOUR_FMT.format(j.d)}</span>
          </header>
          <ul className="flex min-h-16 flex-col gap-1.5 p-2.5">
            {j.lignes.length === 0 ? (
              <li className="py-3 text-center text-xs text-neutral-300 dark:text-neutral-600">—</li>
            ) : (
              j.lignes.map((l) => (
                <li key={l.id} className={`flex items-center gap-2 rounded-lg border px-2.5 py-2 ${l.fait ? 'border-emerald-200 bg-emerald-50/60 dark:border-emerald-900 dark:bg-emerald-950/20' : 'border-neutral-100 dark:border-navy-700'}`}>
                  {l.genre === 'prospect' ? <Sprout size={13} className="shrink-0 text-accent" aria-label="Prospect" /> : l.genre === 'adm' ? <Briefcase size={13} className="shrink-0 text-neutral-400" aria-label="ADM" /> : <Store size={13} className="shrink-0 text-brand" aria-label="Client" />}
                  {l.classe ? <ClassBadge value={l.classe} size="xs" /> : null}
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-xs font-medium">{l.titre}</p>
                    {l.heure || l.ville ? <p className="truncate text-[11px] text-neutral-400">{[l.heure, l.ville].filter(Boolean).join(' · ')}</p> : null}
                    {l.note ? <p className="truncate text-[11px] italic text-neutral-400">{l.note}</p> : null}
                  </div>
                  {l.fait ? <CheckCircle2 size={14} className="shrink-0 text-emerald-500" aria-label="Fait" /> : <Circle size={12} className="shrink-0 text-neutral-300" aria-label="Pas encore fait" />}
                </li>
              ))
            )}
          </ul>
        </section>
      ))}
    </div>
  );
}

/** Planning d'un chef de secteur (tournée : clients, prospects, ADM) — lecture seule. */
export function PlanningCs({ lundi, etapes }: { lundi: Date; etapes: TourneeEtapeRow[] }) {
  const lignes = etapes.map((e) => ({ date: e.datePassage.slice(0, 10), l: ligneDepuisEtape(e) }));
  return <GrilleSemaine lundi={lundi} lignesDuJour={(d) => lignes.filter((x) => x.date === d).map((x) => x.l)} />;
}

/** Planning d'un promoteur (visites chez des clients) — lecture ; la modification passe par ABC Sales. */
export function PlanningPromoteur({ lundi, visites }: { lundi: Date; visites: PlanningItem[] }) {
  const lignes = visites.map((v) => ({ date: v.datePassage.slice(0, 10), l: ligneDepuisVisite(v) }));
  return <GrilleSemaine lundi={lundi} lignesDuJour={(d) => lignes.filter((x) => x.date === d).map((x) => x.l)} />;
}

/** Carte « Rapport d'activité » de la semaine affichée (prévu / réalisé, écarts, statut). */
export function CarteRapport({ rapport, semaineLibelle }: { rapport: RapportDetail | null; semaineLibelle: string }) {
  if (!rapport) {
    return (
      <section className={`${CARTE} p-5`} aria-labelledby="rapport-titre">
        <h2 id="rapport-titre" className="font-semibold">Rapport d&apos;activité</h2>
        <p className="mt-2 text-sm text-neutral-400">Rapport indisponible pour cette semaine (hors de votre périmètre ou API injoignable).</p>
      </section>
    );
  }
  const { etat, prevue, realisee } = rapport;
  const ecarts = calculerEcarts(prevue, realisee);
  const valide = etat.statut === 'VALIDE' || etat.statut === 'VALIDE_AUTO';
  const faites = realisee.filter((l) => l.fait).length;
  return (
    <section className={`${CARTE} p-5`} aria-labelledby="rapport-titre">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 id="rapport-titre" className="font-semibold">Rapport d&apos;activité</h2>
          <p className="text-xs text-neutral-400">{semaineLibelle}</p>
        </div>
        <Pastille ton={valide ? 'ok' : 'cours'}>{etat.statut === 'EN_COURS' ? 'En cours' : LIBELLE_STATUT_RAPPORT[etat.statut]}</Pastille>
      </div>
      {prevue === null ? (
        <p className="mt-3 text-sm text-neutral-500">Prévision non renseignée cette semaine : pas de comparaison possible.</p>
      ) : (
        <>
          <p className="mt-3 text-sm font-semibold text-brand dark:text-accent">
            Prévu {prevue.length} · Réalisé {realisee.length} <span className="font-normal text-neutral-400">({faites} fait{faites > 1 ? 's' : ''})</span>
          </p>
          <p className="mt-1 text-sm text-neutral-600 dark:text-neutral-300">{resumeEcarts(ecarts)}</p>
          {ecarts && ecarts.details.length > 0 ? (
            <ul className="mt-3 flex flex-col gap-1.5">
              {ecarts.details.map((d, i) => (
                <li key={`${d.type}-${i}`} className="flex items-start gap-2 rounded-lg border border-neutral-100 px-3 py-2 text-sm dark:border-navy-700">
                  <span className="mt-0.5 shrink-0 text-xs font-semibold text-neutral-400">{d.type === 'ajoutee' ? 'Ajoutée' : d.type === 'retiree' ? 'Retirée' : 'Déplacée'}</span>
                  <span className="min-w-0">
                    <span className="block truncate font-medium">{d.titre}</span>
                    <span className="block text-xs text-neutral-400">{d.detail}</span>
                  </span>
                </li>
              ))}
            </ul>
          ) : null}
        </>
      )}
      {valide && etat.valideAt ? <p className="mt-3 text-xs text-neutral-400">Validé le {DATE_HEURE.format(new Date(etat.valideAt))}{etat.valideAuto ? ' automatiquement' : ''}.</p> : null}
    </section>
  );
}

function Vide({ children }: { children: React.ReactNode }) {
  return <p className={`${CARTE} px-5 py-8 text-center text-sm text-neutral-400`}>{children}</p>;
}

function Tronque({ tronque }: { tronque: boolean }) {
  return tronque ? (
    <p className="text-xs text-neutral-400">
      Liste limitée aux éléments les plus récents : l&apos;API ne permet pas encore de filtrer par utilisateur.
    </p>
  ) : null;
}

/** Visites (lecture seule) : client, date, nombre de photos. */
export function ListeVisites({ visites, tronque, titre }: { visites: VisiteActivite[] | null; tronque: boolean; titre: string }) {
  if (visites === null) return <Vide>Visites indisponibles — l&apos;API est-elle démarrée ?</Vide>;
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-neutral-500">{titre} · {visites.length}</p>
      {visites.length === 0 ? (
        <Vide>Aucune visite trouvée.</Vide>
      ) : (
        <ul className="flex flex-col gap-2">
          {visites.map((v) => (
            <li key={v.id} className={`${CARTE} flex items-center gap-3 px-4 py-3`}>
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium">{v.client?.enseigne ?? '—'}</p>
                <p className="truncate text-xs text-neutral-500">
                  {DATE_HEURE.format(new Date(v.createdAt))}
                  {v.client?.ville ? ` · ${v.client.ville}` : ''}
                </p>
              </div>
              <Pastille ton="ok">Envoyée</Pastille>
            </li>
          ))}
        </ul>
      )}
      <Tronque tronque={tronque} />
    </div>
  );
}

/** Commandes (lecture seule) : montant, n°, client, date, badge Livrée / Pas livrée. */
export function ListeCommandes({ commandes, tronque, titre }: { commandes: CommandeRow[] | null; tronque: boolean; titre: string }) {
  if (commandes === null) return <Vide>Commandes indisponibles — l&apos;API est-elle démarrée ?</Vide>;
  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-neutral-500">{titre} · {commandes.length}</p>
      {commandes.length === 0 ? (
        <Vide>Aucune commande trouvée.</Vide>
      ) : (
        <ul className="flex flex-col gap-2">
          {commandes.map((c) => (
            <li key={c.id}>
              <Link href={`/commandes/${c.id}`} className={`${CARTE} flex items-center gap-3 px-4 py-3 transition hover:shadow-md ${FOCUS}`}>
                <div className="min-w-0 flex-1">
                  <p className="font-medium tabular-nums">{EUR2.format(c.total)} <span className="text-xs font-normal text-neutral-400">HT</span></p>
                  <p className="truncate text-xs text-neutral-500">
                    {c.numero} · {c.client?.enseigne ?? c.raisonSocialeCmd ?? '—'}
                    {c.dateCommande ? ` · ${DATE_FMT.format(new Date(c.dateCommande))}` : ''}
                  </p>
                </div>
                {c.annulee ? (
                  <Pastille>Annulée</Pastille>
                ) : c.statutLivraison ? (
                  <span title={c.statutLivraison === 'LIVREE_PARTIELLE' ? 'Livrée partiellement' : undefined}>
                    <Pastille ton={c.statutLivraison === 'LIVREE' ? 'ok' : 'neutre'}>{c.statutLivraison === 'LIVREE' ? 'Livrée' : 'Pas livrée'}</Pastille>
                  </span>
                ) : null}
              </Link>
            </li>
          ))}
        </ul>
      )}
      <Tronque tronque={tronque} />
    </div>
  );
}
