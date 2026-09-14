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
  Sparkles,
  CheckCircle2,
} from 'lucide-react';
import {
  getProspect,
  getProspectHistorique,
  PROSPECT_STATUTS,
  type OpportuniteRow,
} from '@/lib/api';
import { StatutBadge, STATUT_LABELS, SOURCE_LABELS } from '@/components/prospect-badges';
import { updateProspect, convertProspect } from '@/lib/prospect-actions';

export const metadata = { title: 'Fiche prospect — Helios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
const fmt = (d: string | null | undefined) => (d ? DT.format(new Date(d)) : '—');

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
  const [p, histo] = await Promise.all([getProspect(id), getProspectHistorique(id)]);
  if (!p) notFound();

  const opportunites = p.opportunites ?? histo?.opportunites ?? [];
  const visites = histo?.visites ?? [];

  return (
    <div className="flex flex-col gap-5">
      <Link href="/pilotage/prospects" className="inline-flex w-fit items-center gap-1 text-sm text-neutral-500 hover:text-brand dark:hover:text-accent">
        <ArrowLeft size={15} /> Retour à la prospection
      </Link>

      {/* En-tête */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold">{p.enseigne}</h1>
            <StatutBadge value={p.statut} />
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

        {/* Actions : changement d'étape + conversion */}
        <div className="flex items-center gap-2">
          <form action={updateProspect} className="flex items-center gap-1.5">
            <input type="hidden" name="id" value={p.id} />
            <select
              name="statut"
              defaultValue={p.statut}
              className="rounded-lg border border-neutral-200 bg-white px-2 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
            >
              {PROSPECT_STATUTS.map((s) => (
                <option key={s} value={s}>
                  {STATUT_LABELS[s]}
                </option>
              ))}
            </select>
            <button type="submit" className="rounded-lg bg-neutral-100 px-3 py-1.5 text-sm font-medium transition hover:bg-neutral-200 dark:bg-navy-800 dark:hover:bg-navy-700">
              Enregistrer
            </button>
          </form>
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
            <Info icon={MapPin} label="Adresse" value={[p.adresse1, [p.codePostal, p.ville].filter(Boolean).join(' ')].filter(Boolean).join(', ') || '—'} />
            <Info icon={Phone} label="Téléphone" value={p.telephone ?? '—'} />
            <Info icon={Mail} label="Email" value={p.email ?? '—'} />
            <Info icon={User} label="Responsable" value={p.assignedTo?.displayName ?? '—'} />
            <Info icon={MapPin} label="Secteur" value={p.secteur ? `${p.secteur.nom} (${p.secteur.code})` : '—'} />
            {p.statut === 'PERDU' && p.motifPerte ? (
              <Info icon={Target} label="Motif de perte" value={MOTIF_LABELS[p.motifPerte] ?? p.motifPerte} />
            ) : null}
            <Info icon={CalendarClock} label="Créé le" value={fmt(p.createdAt)} />
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
              Visites de prospection
              <span className="ml-auto text-xs font-normal text-neutral-400">{visites.length}</span>
            </h2>
            {visites.length === 0 ? (
              <p className="px-5 py-6 text-sm text-neutral-400">Aucune visite enregistrée.</p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {visites.map((v) => (
                  <li key={v.id} className="px-5 py-3">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">{v.motif ?? 'Visite'}</span>
                      <span className="ml-auto text-xs text-neutral-400">{fmt(v.createdAt)}</span>
                    </div>
                    {v.commentaire ? <p className="mt-0.5 text-sm text-neutral-500">{v.commentaire}</p> : null}
                    {v.promoteur ? <p className="mt-0.5 text-xs text-neutral-400">par {v.promoteur.displayName}</p> : null}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
