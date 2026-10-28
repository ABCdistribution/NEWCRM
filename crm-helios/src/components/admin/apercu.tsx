import Link from 'next/link';
import { Activity, Database, Network, Smartphone, UserCheck, Users } from 'lucide-react';
import type { AdminApercu } from '@/lib/api';
import { ROLE_LABELS } from '@/components/badges';

type Ton = 'ok' | 'attention' | 'neutre';

const TON: Record<Ton, string> = {
  ok: 'text-emerald-600',
  attention: 'text-amber-600',
  neutre: 'text-neutral-900',
};

const dateFr = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short' });

/** Un indicateur : valeur, libellé, et lien optionnel vers l'onglet concerné. Simple compteur, sans état. */
function Indicateur({
  libelle,
  valeur,
  ton = 'neutre',
  detail,
  href,
}: {
  libelle: string;
  valeur: string | number;
  ton?: Ton;
  detail?: string;
  href?: string;
}) {
  const corps = (
    <>
      <p className={`text-2xl font-bold tabular-nums ${TON[ton]}`}>{valeur}</p>
      <p className="mt-0.5 text-sm text-neutral-700">{libelle}</p>
      {detail ? <p className="mt-0.5 text-xs text-neutral-400">{detail}</p> : null}
    </>
  );
  const classes = 'block rounded-xl border border-neutral-100 bg-neutral-50/60 px-4 py-3';
  return href ? (
    <Link href={href} className={`${classes} transition hover:border-violet-200 hover:bg-violet-50/40`}>
      {corps}
    </Link>
  ) : (
    <div className={classes}>{corps}</div>
  );
}

function Carte({ titre, icone: Icone, children }: { titre: string; icone: typeof Users; children: React.ReactNode }) {
  return (
    <section className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 text-sm font-semibold">
        <Icone size={16} className="text-violet-600" aria-hidden />
        {titre}
      </h2>
      <div className="grid grid-cols-2 gap-3 p-4">{children}</div>
    </section>
  );
}

const STATUT_IMPORT: Record<string, { label: string; ton: Ton }> = {
  SUCCESS: { label: 'Réussi', ton: 'ok' },
  FAILED: { label: 'En échec', ton: 'attention' },
  PROCESSING: { label: 'En cours', ton: 'neutre' },
  PENDING: { label: 'En attente', ton: 'neutre' },
};

/** Vue d'ensemble : uniquement des indicateurs calculés à la volée, chacun renvoyant vers l'onglet concerné. */
export function AdminApercuOnglet({ data }: { data: AdminApercu }) {
  const o = data.organisation;
  const imp = data.imports.dernier;
  const statut = imp ? STATUT_IMPORT[imp.status] : null;
  const lien = (onglet: string) => `/pilotage/admin?onglet=${onglet}`;

  return (
    <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
      <Carte titre="Santé de la plateforme" icone={Activity}>
        <Indicateur libelle="API" valeur="Opérationnelle" ton="ok" />
        <Indicateur
          libelle="Base de données"
          valeur={data.sante.db === 'up' ? 'Opérationnelle' : 'Indisponible'}
          ton={data.sante.db === 'up' ? 'ok' : 'attention'}
        />
      </Carte>

      <Carte titre="Comptes" icone={Users}>
        <Indicateur libelle="Comptes actifs" valeur={data.utilisateurs.actifs} href={lien('utilisateurs')} />
        <Indicateur
          libelle="Comptes désactivés"
          valeur={data.utilisateurs.inactifs}
          ton={data.utilisateurs.inactifs > 0 ? 'attention' : 'ok'}
          href={lien('utilisateurs')}
        />
        {Object.entries(data.utilisateurs.parRole).map(([role, n]) => (
          <Indicateur key={role} libelle={ROLE_LABELS[role] ?? role} valeur={n} href={lien('utilisateurs')} />
        ))}
      </Carte>

      <Carte titre="Cohérence de l'organisation" icone={Network}>
        <Indicateur libelle="Secteurs" valeur={o.secteurs} href={lien('organisation')} />
        <Indicateur
          libelle="Secteurs sans chef"
          valeur={o.secteursSansChef}
          ton={o.secteursSansChef > 0 ? 'attention' : 'ok'}
          href={lien('organisation')}
        />
        <Indicateur
          libelle="Promoteurs sans secteur"
          valeur={o.commerciauxSansSecteur}
          ton={o.commerciauxSansSecteur > 0 ? 'attention' : 'ok'}
          href={lien('organisation')}
        />
        <Indicateur
          libelle="Promoteurs sans directeur"
          valeur={o.commerciauxSansDirecteur}
          ton={o.commerciauxSansDirecteur > 0 ? 'attention' : 'ok'}
          href={lien('organisation')}
        />
        <Indicateur
          libelle="Promoteurs sans code ERP"
          valeur={o.commerciauxSansCode}
          ton={o.commerciauxSansCode > 0 ? 'attention' : 'ok'}
          href={lien('utilisateurs')}
        />
      </Carte>

      <Carte titre="Synchronisations et imports" icone={Database}>
        <Indicateur
          libelle="Dernier import"
          valeur={statut?.label ?? '—'}
          ton={statut?.ton ?? 'neutre'}
          detail={imp ? `${imp.fileName} · ${dateFr.format(new Date(imp.date))}` : 'Aucun import enregistré'}
          href={lien('synchros')}
        />
        <Indicateur
          libelle="Imports en échec (7 jours)"
          valeur={data.imports.enEchec7j}
          ton={data.imports.enEchec7j > 0 ? 'attention' : 'ok'}
          href={lien('synchros')}
        />
        <Indicateur
          libelle="Lignes rejetées (dernier import)"
          valeur={imp?.rowsFailed ?? 0}
          ton={imp && imp.rowsFailed > 0 ? 'attention' : 'ok'}
          detail={imp ? `sur ${imp.rowsTotal} lignes` : undefined}
          href={lien('synchros')}
        />
      </Carte>

      <section className="rounded-2xl border border-dashed border-neutral-300 bg-white p-5 xl:col-span-2">
        <h2 className="flex items-center gap-2 text-sm font-semibold text-neutral-600">
          <Smartphone size={16} aria-hidden />
          Téléphones terrain
        </h2>
        <p className="mt-1 flex items-start gap-2 text-sm text-neutral-500">
          <UserCheck size={15} className="mt-0.5 shrink-0" aria-hidden />
          Les indicateurs mobiles (appareils actifs, en retard, versions) seront disponibles quand l&apos;application
          remontera son état à chaque synchronisation. Voir l&apos;onglet Mobile.
        </p>
      </section>
    </div>
  );
}
