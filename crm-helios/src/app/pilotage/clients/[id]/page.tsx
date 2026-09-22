import Link from 'next/link';
import { notFound } from 'next/navigation';
import {
  ArrowLeft,
  ExternalLink,
  Building2,
  Store,
  Phone,
  Mail,
  Users,
  StickyNote,
  CalendarClock,
  Footprints,
  ShoppingCart,
  Landmark,
  MapPin,
  Smartphone,
} from 'lucide-react';
import { getClient, getClientHistorique, getMe, idReprVariants } from '@/lib/api';
import { ActiveBadge } from '@/components/badges';
import { CaChart } from '@/components/ca-chart';
import { ContactsCard } from '@/components/contacts-card';

export const metadata = { title: 'Fiche magasin — Helios' };

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });

/** Pastille de classe A→G, colorée selon le niveau. */
function ClassBadge({ value }: { value: string | null }) {
  if (!value) return <span className="text-neutral-400">—</span>;
  const colors: Record<string, string> = {
    A: 'bg-emerald-500/10 text-emerald-600',
    B: 'bg-green-500/10 text-green-600',
    C: 'bg-lime-500/10 text-lime-600',
    D: 'bg-yellow-500/10 text-yellow-600',
    E: 'bg-amber-500/10 text-amber-600',
    F: 'bg-orange-500/10 text-orange-600',
    G: 'bg-red-500/10 text-red-600',
  };
  return (
    <span
      className={`inline-flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${colors[value] ?? 'bg-neutral-500/10 text-neutral-600'}`}
    >
      {value}
    </span>
  );
}

function Field({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div>
      <dt className="text-xs text-neutral-400">{label}</dt>
      <dd className="text-sm">{value || '—'}</dd>
    </div>
  );
}

const card =
  'rounded-2xl bg-white shadow-card';
const cardHeader =
  'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700';

const EUR = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

export default async function ClientFiche({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [client, histo, me] = await Promise.all([getClient(id), getClientHistorique(id), getMe()]);
  if (!client) notFound();

  // Formes équivalentes de MON code représentant, pour repérer mes commandes.
  const mesCodes = me?.idRepr ? idReprVariants(me.idRepr) : [];

  const adresse = [client.adresse1, client.adresse2, client.adresse3].filter(Boolean).join(', ');
  const villeLigne = [client.codePostal, client.ville].filter(Boolean).join(' ');

  return (
    <div className="flex flex-col gap-5">
      {/* En-tête */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <Link
            href="/pilotage/clients"
            className="mt-1 rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-neutral-700 dark:hover:bg-navy-800"
            aria-label="Retour à mes magasins"
          >
            <ArrowLeft size={18} />
          </Link>
          <div>
            <div className="flex flex-wrap items-center gap-2.5">
              <h1 className="text-2xl font-bold">{client.enseigne || client.raisonSociale}</h1>
              <ClassBadge value={client.niveauClass} />
              <ActiveBadge active={client.actif} />
            </div>
            <p className="mt-0.5 text-sm text-neutral-500">
              {client.raisonSociale}
              <span className="mx-1.5 text-neutral-300">·</span>
              <span className="font-mono text-xs">{client.codeAs400}</span>
            </p>
          </div>
        </div>

        {/* Compteurs historique + outil AscendoPilot */}
        <div className="flex gap-2">
          <a
            href="https://ascendopilot.abcosmetique.com/magasins"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 rounded-lg bg-[#0faf6f] px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-[#0c9a61]"
          >
            <ExternalLink size={14} /> AscendoPilot
          </a>
          <span className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-1.5 text-xs text-neutral-500 dark:border-navy-700">
            <Footprints size={14} className="text-brand" />
            {client._count.visites} tournée{client._count.visites > 1 ? 's' : ''}
          </span>
          <span className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-1.5 text-xs text-neutral-500 dark:border-navy-700">
            <ShoppingCart size={14} className="text-brand" />
            {client._count.commandes} commande{client._count.commandes > 1 ? 's' : ''}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        {/* Colonne 1 — Identité Minos (lecture seule) */}
        <section className={card}>
          <h2 className={cardHeader}>
            <Building2 size={17} className="text-brand" />
            Identité
            <span className="ml-auto rounded-full bg-neutral-100 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-neutral-400 dark:bg-navy-800">
              Minos · lecture
            </span>
          </h2>
          <dl className="grid grid-cols-2 gap-x-4 gap-y-3 px-5 py-4">
            <div className="col-span-2">
              <dt className="text-xs text-neutral-400">Adresse</dt>
              <dd className="flex items-start gap-1.5 text-sm">
                <MapPin size={14} className="mt-0.5 shrink-0 text-neutral-400" />
                <span>
                  {adresse || '—'}
                  {villeLigne ? (
                    <>
                      <br />
                      {villeLigne}
                    </>
                  ) : null}
                  {client.pays ? <span className="text-neutral-400"> · {client.pays}</span> : null}
                </span>
              </dd>
            </div>
            <Field label="SIRET" value={client.siret} />
            <Field label="Forme" value={client.formeEntreprise} />
            <Field label="EAN client" value={client.eanClient} />
            <Field label="Devise" value={client.devise} />
            <div>
              <dt className="text-xs text-neutral-400">Téléphone</dt>
              <dd className="flex items-center gap-1.5 text-sm">
                <Phone size={13} className="text-neutral-400" />
                {client.tel1 || '—'}
                {client.tel2 ? <span className="text-neutral-400">/ {client.tel2}</span> : null}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-neutral-400">Email</dt>
              <dd className="flex items-center gap-1.5 text-sm">
                <Mail size={13} className="text-neutral-400" />
                <span className="truncate">{client.email || '—'}</span>
              </dd>
            </div>
            <Field label="Statut commande" value={client.statutCommande} />
            <Field label="Statut livraison" value={client.statutLivre} />
          </dl>
        </section>

        {/* Colonne 2 — Organisation commerciale */}
        <section className="flex flex-col gap-5">
          <div className={card}>
            <h2 className={cardHeader}>
              <Landmark size={17} className="text-brand" />
              Organisation
            </h2>
            <dl className="grid grid-cols-1 gap-3 px-5 py-4">
              <Field
                label="Secteur"
                value={client.secteur ? `${client.secteur.nom} (${client.secteur.code})` : null}
              />
              <Field
                label="Centrale d'achat"
                value={client.centrale ? `${client.centrale.nom} (${client.centrale.code})` : null}
              />
              <div>
                <dt className="text-xs text-neutral-400">Commerciaux</dt>
                <dd className="mt-1 flex flex-wrap gap-1.5">
                  {client.commerciaux.length === 0 ? (
                    <span className="text-sm text-neutral-400">Aucun commercial affecté</span>
                  ) : (
                    client.commerciaux.map((u) => (
                      <span
                        key={u.id}
                        className="inline-flex items-center gap-1 rounded-full bg-brand/10 dark:bg-accent/10 px-2.5 py-1 text-xs font-medium text-brand dark:text-accent"
                      >
                        <Users size={12} />
                        {u.displayName}
                        {u.idRepr ? <span className="font-mono opacity-60">({u.idRepr})</span> : null}
                      </span>
                    ))
                  )}
                </dd>
              </div>
            </dl>
          </div>

          <div className={card}>
            <h2 className={cardHeader}>
              <CalendarClock size={17} className="text-brand" />
              Périodicité de tournée
            </h2>
            <div className="px-5 py-4">
              {client.periodicites.length === 0 ? (
                <p className="text-sm text-neutral-400">Aucune périodicité définie.</p>
              ) : (
                <p className="text-sm font-medium">{client.periodicites[0].periodicite.libelle}</p>
              )}
            </div>
          </div>
        </section>

        {/* Colonne 3 — Contacts + Notes (CRM, éditable à terme) */}
        <section className="flex flex-col gap-5">
          <ContactsCard clientId={client.id} contacts={client.contacts} />

          <div className={card}>
            <h2 className={cardHeader}>
              <StickyNote size={17} className="text-brand" />
              Notes terrain
              <span className="ml-auto rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
                {client.notes.length}
              </span>
            </h2>
            {client.notes.length === 0 ? (
              <p className="px-5 py-4 text-sm text-neutral-400">Aucune note.</p>
            ) : (
              <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                {client.notes.map((n) => (
                  <li key={n.id} className="px-5 py-3">
                    <p className="text-sm">{n.remarque}</p>
                    <p className="mt-1 text-xs text-neutral-400">
                      {n.auteur?.displayName ?? 'Inconnu'} · {DATE_FMT.format(new Date(n.createdAt))}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>

      {/* Historique : CA N/N-1 + commandes + visites */}
      {histo ? (
        <>
          <section className={card}>
            <h2 className={cardHeader}>
              <Store size={17} className="text-brand" />
              Chiffre d&apos;affaires mensuel — {histo.ca.anneeN - 1} vs {histo.ca.anneeN}
            </h2>
            <CaChart anneeN={histo.ca.anneeN} courbeN={histo.ca.courbeN} courbeN1={histo.ca.courbeN1} />
          </section>

          <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
            {/* Dernières commandes */}
            <section className={card}>
              <h2 className={cardHeader}>
                <ShoppingCart size={17} className="text-brand" />
                Dernières commandes
              </h2>
              {histo.commandes.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">Aucune commande pour ce magasin.</p>
              ) : (
                <table className="w-full text-sm">
                  <thead className="text-left text-xs text-neutral-400">
                    <tr className="border-b border-neutral-100 dark:border-navy-700">
                      <th className="px-5 py-2 font-medium">N°</th>
                      <th className="px-2 py-2 font-medium">Date</th>
                      <th className="px-2 py-2 font-medium">Repr</th>
                      <th className="px-2 py-2 text-right font-medium">Lignes</th>
                      <th className="px-2 py-2 text-right font-medium">Total</th>
                      <th className="px-5 py-2 text-right font-medium">Statut</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                    {histo.commandes.map((c) => {
                      const mienne = c.idRepr != null && mesCodes.includes(c.idRepr);
                      return (
                        <tr key={c.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                          <td className="px-5 py-2.5 font-mono text-xs font-medium text-brand dark:text-accent">
                            <Link href={`/pilotage/commandes/${c.id}`} className="absolute inset-0" aria-label={`Commande ${c.numero}`} />
                            {c.numero}
                            {c.viaMobile ? (
                              <Smartphone size={11} className="ml-1 inline text-neutral-400" aria-label="Saisie mobile" />
                            ) : null}
                          </td>
                          <td className="px-2 py-2.5 text-neutral-500">
                            {c.dateCommande ? DATE_FMT.format(new Date(c.dateCommande)) : '—'}
                          </td>
                          <td className="px-2 py-2.5">
                            {mienne ? (
                              <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
                                moi
                              </span>
                            ) : (
                              <span className="font-mono text-xs text-neutral-400">{c.idRepr ?? '—'}</span>
                            )}
                          </td>
                          <td className="px-2 py-2.5 text-right text-neutral-500">{c.nbLignes}</td>
                          <td className="px-2 py-2.5 text-right font-medium dark:text-accent">{EUR.format(c.total)}</td>
                          <td className="px-5 py-2.5 text-right">
                            {c.annulee ? (
                              <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-xs font-medium text-red-600">
                                Annulée
                              </span>
                            ) : (
                              <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-600">
                                Validée
                              </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </section>

            {/* Dernières tournées */}
            <section className={card}>
              <h2 className={cardHeader}>
                <Footprints size={17} className="text-brand" />
                Dernières tournées
              </h2>
              {histo.visites.length === 0 ? (
                <p className="px-5 py-4 text-sm text-neutral-400">
                  Aucune tournée enregistrée — elles remonteront de l&apos;app mobile.
                </p>
              ) : (
                <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
                  {histo.visites.map((v) => (
                    <li key={v.id} className="flex items-center gap-3 px-5 py-3">
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium">{v.promoteur.displayName}</p>
                        <p className="text-xs text-neutral-400">
                          {DATE_FMT.format(new Date(v.createdAt))}
                          {v._count.photos > 0 ? ` · ${v._count.photos} photo${v._count.photos > 1 ? 's' : ''}` : ''}
                        </p>
                      </div>
                      <div className="flex shrink-0 gap-2 text-xs">
                        {v.dnAbc != null ? (
                          <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 font-medium text-brand">
                            DN ABC {v.dnAbc}
                          </span>
                        ) : null}
                        {v.pem ? (
                          <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 font-medium text-emerald-600">
                            PEM
                          </span>
                        ) : null}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>
        </>
      ) : (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/50 dark:bg-amber-950/30 dark:text-amber-300">
          Historique indisponible — l&apos;API est-elle démarrée ?
        </p>
      )}
    </div>
  );
}
