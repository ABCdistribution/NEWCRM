import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
  ArrowLeft,
  MapPin,
  Phone,
  Mail,
  User,
  Target,
  TrendingUp,
  CalendarClock,
  PhoneCall,
  Footprints,
  Sparkles,
  CheckCircle2,
} from 'lucide-react';
import {
  getProspect,
  getProspectTimeline,
  PROSPECT_STATUTS,
  type OpportuniteRow,
  type ResultatAppel,
} from '@/lib/api';
import { StatutBadge, STATUT_LABELS, SOURCE_LABELS } from '@/components/prospect-badges';
import { ClassBadge } from '@/components/class-badge';
import { convertProspect } from '@/lib/prospect-actions';
import { ProspectContactActions } from '@/components/prospect-contact-actions';
import {
  ProspectEtapesStepper,
  ProspectNoteForm,
  ProspectPlanifierButton,
} from '@/components/prospect-fiche-actions';
import { ProspectCoordonnees } from '@/components/prospect-coordonnees';
import { ProspectPiecesJointes } from '@/components/prospect-pieces-jointes';
import { listPiecesJointes } from '@/lib/prospect-actions';

export const metadata = { title: 'Fiche prospect — Helios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
const fmt = (d: string | null | undefined) => (d ? DT.format(new Date(d)) : '—');

const APPEL_LABELS: Record<ResultatAppel, string> = {
  REPONDU: 'Répondu',
  SANS_REPONSE: 'Sans réponse',
  MESSAGERIE: 'Messagerie',
  RAPPEL_PREVU: 'Rappel prévu',
};
const APPEL_BADGE: Record<ResultatAppel, string> = {
  REPONDU: 'bg-emerald-500/12 text-emerald-600 dark:text-emerald-400',
  SANS_REPONSE: 'bg-red-500/12 text-red-500',
  MESSAGERIE: 'bg-amber-500/15 text-amber-600 dark:text-amber-400',
  RAPPEL_PREVU: 'bg-sky-500/12 text-sky-600 dark:text-sky-400',
};
/** « 4 min 30 » à partir d'une durée en secondes. */
function duree(sec: number): string {
  const m = Math.floor(sec / 60);
  const r = sec % 60;
  return m > 0 ? `${m} min${r ? ` ${r.toString().padStart(2, '0')}` : ''}` : `${sec} s`;
}

const MOTIF_LABELS: Record<string, string> = {
  PRIX: 'Prix', CONCURRENCE: 'Concurrence', PAS_DE_BESOIN: 'Pas de besoin', SANS_REPONSE: 'Sans réponse', AUTRE: 'Autre',
};
const OPP_TYPE_LABELS: Record<string, string> = {
  REFERENCEMENT: 'Référencement', OP: 'OP', MISE_EN_AVANT: 'Mise en avant',
};
const OPP_STATUT_STYLES: Record<string, string> = {
  OUVERTE: 'bg-sky-500/15 text-sky-500',
  GAGNEE: 'bg-emerald-500/15 text-emerald-500',
  PERDUE: 'bg-red-500/15 text-red-400',
  ANNULEE: 'bg-neutral-400/15 text-neutral-500',
};

const card = 'rounded-2xl bg-white shadow-card';
const cardHeader = 'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700';

function Info({ icon: Icon, label, value }: { icon: typeof MapPin; label: string; value: string }) {
  return (
    <div className="flex items-start gap-2.5">
      <Icon size={15} className="mt-0.5 shrink-0 text-neutral-400" />
      <div>
        <p className="text-[11px] uppercase tracking-wide text-neutral-400">{label}</p>
        <p className="text-sm">{value}</p>
      </div>
    </div>
  );
}

function OpportuniteLine({ o }: { o: OpportuniteRow }) {
  return (
    <li className="flex items-center gap-3 px-5 py-2.5">
      <Sparkles size={14} className="shrink-0 text-[#A78BDA]" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{o.libelle ?? OPP_TYPE_LABELS[o.type] ?? o.type}</p>
        <p className="text-xs text-neutral-400">
          {OPP_TYPE_LABELS[o.type] ?? o.type}
          {o.dateDebut ? ` · ${fmt(o.dateDebut)}` : ''}
          {o.dateFin ? ` → ${fmt(o.dateFin)}` : ''}
        </p>
      </div>
      {o.valeurEstimee != null ? (
        <span className="shrink-0 text-sm font-semibold dark:text-accent">{EUR.format(o.valeurEstimee)}</span>
      ) : null}
      <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${OPP_STATUT_STYLES[o.statut] ?? 'bg-neutral-400/15 text-neutral-500'}`}>
        {o.statut.charAt(0) + o.statut.slice(1).toLowerCase()}
      </span>
    </li>
  );
}

export default async function ProspectDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [p, timeline, pieces] = await Promise.all([getProspect(id), getProspectTimeline(id), listPiecesJointes(id)]);
  if (!p) notFound();

  const opportunites = p.opportunites ?? [];
  // Timeline unifiée : appels (mobile) + visites de prospection — les opportunités ont leur carte.
  const evenements = (timeline ?? []).filter((e) => e.type !== 'OPPORTUNITE');

  return (
    <div className="flex flex-col gap-5">
      <Link href="/pilotage/prospects" className="inline-flex w-fit items-center gap-1 text-sm text-neutral-500 hover:text-brand dark:hover:text-accent">
        <ArrowLeft size={15} /> Retour à la prospection
      </Link>

      {/* En-tête */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-3">
            <ClassBadge value={p.niveauClass ?? null} />
            <h1 className="text-2xl font-bold">{p.enseigne}</h1>
            <StatutBadge value={p.statut} />
            <ProspectContactActions prospectId={p.id} telephone={p.telephone} email={p.email} />
            {p.clientId ? (
              <Link href={`/pilotage/clients/${p.clientId}`} className="inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-2 py-0.5 text-xs font-medium text-emerald-500">
                <CheckCircle2 size={12} /> Converti en client
              </Link>
            ) : null}
          </div>
          <p className="text-sm text-neutral-500">
            {p.raisonSociale}
            {p.source ? ` · Source : ${SOURCE_LABELS[p.source] ?? p.source}` : ''}
          </p>
        </div>

        {/* Actions : planification + conversion */}
        <div className="flex items-center gap-2">
          <ProspectPlanifierButton prospectId={p.id} />
          {p.statut === 'GAGNE' && !p.clientId ? (
            <form action={convertProspect}>
              <input type="hidden" name="id" value={p.id} />
              <button type="submit" className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-emerald-700">
                <CheckCircle2 size={15} /> Convertir en client
              </button>
            </form>
          ) : null}
        </div>
      </div>

      {/* Pipeline : étapes cliquables, changement journalisé dans la timeline */}
      <ProspectEtapesStepper prospectId={p.id} statut={p.statut} />

      {/* KPIs */}
      <section className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <div className={`${card} p-5`}>
          <div className="flex items-center justify-between">
            <span className="text-sm text-neutral-500">Potentiel CA/an</span>
            <TrendingUp size={17} className="text-[#7D8CCE]" />
          </div>
          <p className="mt-2 text-2xl font-bold text-brand dark:text-accent">
            {p.potentielCaAnnuel != null ? EUR.format(p.potentielCaAnnuel) : '—'}
          </p>
        </div>
        <div className={`${card} p-5`}>
          <div className="flex items-center justify-between">
            <span className="text-sm text-neutral-500">Probabilité</span>
            <Target size={17} className="text-[#7D8CCE]" />
          </div>
          <p className="mt-2 text-2xl font-bold text-brand dark:text-accent">
            {p.probabilite != null ? `${p.probabilite}%` : '—'}
          </p>
        </div>
        <div className={`${card} p-5`}>
          <div className="flex items-center justify-between">
            <span className="text-sm text-neutral-500">Valeur pondérée</span>
            <Sparkles size={17} className="text-[#7D8CCE]" />
          </div>
          <p className="mt-2 text-2xl font-bold text-brand dark:text-accent">
            {p.potentielCaAnnuel != null && p.probabilite != null
              ? EUR.format((p.potentielCaAnnuel * p.probabilite) / 100)
              : '—'}
          </p>
        </div>
      </section>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
        {/* Coordonnées */}
        <section className={`${card} lg:col-span-1`}>
          <h2 className={cardHeader}>Coordonnées</h2>
          <div className="flex flex-col gap-4 px-5 py-4">
            <ProspectCoordonnees
              prospectId={p.id}
              coords={{ adresse1: p.adresse1, codePostal: p.codePostal, ville: p.ville, telephone: p.telephone, email: p.email }}
            />
            <Info icon={User} label="Responsable" value={p.assignedTo?.displayName ?? '—'} />
            <Info icon={MapPin} label="Secteur" value={p.secteur ? `${p.secteur.nom} (${p.secteur.code})` : '—'} />
            {p.statut === 'PERDU' && p.motifPerte ? (
              <Info icon={Target} label="Motif de perte" value={MOTIF_LABELS[p.motifPerte] ?? p.motifPerte} />
            ) : null}
            <Info icon={CalendarClock} label="Créé le" value={fmt(p.createdAt)} />
          </div>

          {/* Pièces jointes (plaquettes, devis, photos…) */}
          <div className="border-t border-neutral-100 dark:border-navy-700">
            <h3 className="px-5 pt-3.5 text-sm font-semibold">Pièces jointes</h3>
            <ProspectPiecesJointes prospectId={p.id} pieces={pieces ?? []} />
          </div>
        </section>

        {/* Opportunités + Visites */}
        <div className="flex flex-col gap-5 lg:col-span-2">
          <section className={card}>
            <h2 className={cardHeader}>
              <Sparkles size={16} className="text-brand dark:text-accent" />
              Opportunités
              <span className="ml-auto text-xs font-normal text-neutral-400">{opportunites.length}</span>
            </h2>
            {opportunites.length === 0 ? (
              <p className="px-5 py-6 text-sm text-neutral-400">Aucune opportunité pour ce prospect.</p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {opportunites.map((o) => (
                  <OpportuniteLine key={o.id} o={o} />
                ))}
              </ul>
            )}
          </section>

          <section className={card}>
            <h2 className={cardHeader}>
              <CalendarClock size={16} className="text-brand dark:text-accent" />
              Timeline — activité du prospect
              <span className="ml-auto text-xs font-normal text-neutral-400">{evenements.length}</span>
            </h2>
            <div className="border-b border-neutral-100 dark:border-navy-700">
              <ProspectNoteForm prospectId={p.id} />
            </div>
            {evenements.length === 0 ? (
              <p className="px-5 py-6 text-sm text-neutral-400">
                Aucune activité — les appels et visites saisis sur l&apos;app mobile apparaîtront ici.
              </p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {evenements.map((e) =>
                  e.type === 'APPEL' ? (
                    <li key={`a-${e.appel.id}`} className="flex gap-3 px-5 py-3">
                      <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-sky-500/12">
                        <PhoneCall size={14} className="text-sky-500" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-medium">Appel téléphonique</span>
                          <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${APPEL_BADGE[e.appel.resultat]}`}>
                            {APPEL_LABELS[e.appel.resultat]}
                          </span>
                          {e.appel.dureeSec != null ? (
                            <span className="text-xs text-neutral-400">{duree(e.appel.dureeSec)}</span>
                          ) : null}
                          <span className="ml-auto text-xs text-neutral-400">{fmt(e.date)}</span>
                        </div>
                        {e.appel.commentaire ? (
                          <p className="mt-0.5 text-sm text-neutral-500">{e.appel.commentaire}</p>
                        ) : null}
                        {e.appel.auteur ? (
                          <p className="mt-0.5 text-xs text-neutral-400">par {e.appel.auteur.displayName}</p>
                        ) : null}
                      </div>
                    </li>
                  ) : e.type === 'EMAIL' ? (
                    <li key={`m-${e.email.id}`} className="flex gap-3 px-5 py-3">
                      <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-violet-500/12">
                        <Mail size={14} className="text-violet-500" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-medium">Email envoyé</span>
                          {e.email.destinataire ? (
                            <span className="text-xs text-neutral-400">{e.email.destinataire}</span>
                          ) : null}
                          <span className="ml-auto text-xs text-neutral-400">{fmt(e.date)}</span>
                        </div>
                        {e.email.sujet ? <p className="mt-0.5 text-sm text-neutral-500">{e.email.sujet}</p> : null}
                        {e.email.commentaire ? (
                          <p className="mt-0.5 text-xs text-neutral-400">{e.email.commentaire}</p>
                        ) : null}
                        {e.email.auteur ? (
                          <p className="mt-0.5 text-xs text-neutral-400">par {e.email.auteur.displayName}</p>
                        ) : null}
                      </div>
                    </li>
                  ) : e.type === 'ETAPE' ? (
                    <li key={`s-${e.etape.id}`} className="flex gap-3 px-5 py-3">
                      <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-amber-500/12">
                        <Target size={14} className="text-amber-500" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-medium">Changement d&apos;étape</span>
                          <span className="text-xs text-neutral-400">
                            {e.etape.de ? STATUT_LABELS[e.etape.de] : 'Fiche créée'} → <span className="font-semibold text-neutral-600 dark:text-neutral-200">{STATUT_LABELS[e.etape.vers]}</span>
                          </span>
                          <span className="ml-auto text-xs text-neutral-400">{fmt(e.date)}</span>
                        </div>
                        {e.etape.commentaire ? (
                          <p className="mt-0.5 text-xs text-neutral-400">Motif : {e.etape.commentaire}</p>
                        ) : null}
                        {e.etape.auteur ? (
                          <p className="mt-0.5 text-xs text-neutral-400">par {e.etape.auteur.displayName}</p>
                        ) : null}
                      </div>
                    </li>
                  ) : e.type === 'NOTE' ? (
                    <li key={`n-${e.note.id}`} className="flex gap-3 px-5 py-3">
                      <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-neutral-500/12">
                        <User size={14} className="text-neutral-500" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-medium">Note</span>
                          <span className="ml-auto text-xs text-neutral-400">{fmt(e.date)}</span>
                        </div>
                        <p className="mt-0.5 text-sm text-neutral-500">{e.note.remarque}</p>
                        {e.note.auteur ? (
                          <p className="mt-0.5 text-xs text-neutral-400">par {e.note.auteur.displayName}</p>
                        ) : null}
                      </div>
                    </li>
                  ) : (
                    <li key={`v-${e.visite.id}`} className="flex gap-3 px-5 py-3">
                      <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-500/12">
                        <Footprints size={14} className="text-emerald-500" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="text-sm font-medium">Visite de prospection</span>
                          {e.visite.motif ? <span className="text-xs text-neutral-400">{e.visite.motif}</span> : null}
                          <span className="ml-auto text-xs text-neutral-400">{fmt(e.date)}</span>
                        </div>
                        {e.visite.pmcCommentaire ? (
                          <p className="mt-0.5 text-sm text-neutral-500">{e.visite.pmcCommentaire}</p>
                        ) : null}
                        {e.visite.promoteur ? (
                          <p className="mt-0.5 text-xs text-neutral-400">par {e.visite.promoteur.displayName}</p>
                        ) : null}
                      </div>
                    </li>
                  ),
                )}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
