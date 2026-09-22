import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Store, ShoppingCart, Smartphone, Truck } from 'lucide-react';
import { getCommande, getMe } from '@/lib/api';
import { LivraisonBadge } from '@/components/livraison-badge';
import { LivraisonEditor } from '@/components/livraison-editor';

export const metadata = { title: 'Commande — Selios' };

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
const QTE = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 });
const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
const DATE_COURT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });

export default async function CommandeDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [commande, me] = await Promise.all([getCommande(id), getMe()]);
  if (!commande) notFound();
  // L'ADV (et direction/admin) tient le suivi de livraison à jour.
  const peutEditerLivraison = !!me && ['ADV', 'DIRECTION', 'ADMIN'].includes(me.role);

  return (
    <div className="flex flex-col gap-5">
      {/* En-tête */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <Link
            href="/commandes"
            className="mt-1 rounded-lg p-1.5 text-neutral-400 transition hover:bg-neutral-100 hover:text-neutral-700 dark:hover:bg-navy-800"
            aria-label="Retour aux commandes"
          >
            <ArrowLeft size={18} />
          </Link>
          <div>
            <div className="flex flex-wrap items-center gap-2.5">
              <h1 className="text-2xl font-bold">
                Commande <span className="font-mono">{commande.numero}</span>
              </h1>
              {commande.annulee ? (
                <span className="rounded-full bg-red-500/10 px-2.5 py-1 text-xs font-medium text-red-600">Annulée</span>
              ) : (
                <span className="rounded-full bg-emerald-500/10 px-2.5 py-1 text-xs font-medium text-emerald-600">Validée</span>
              )}
              <LivraisonBadge statut={commande.statutLivraison} annulee={commande.annulee} />
              {commande.typeCmd ? (
                <span className="rounded bg-neutral-100 px-2 py-0.5 font-mono text-xs text-neutral-500 dark:bg-navy-800">
                  Type {commande.typeCmd}
                </span>
              ) : null}
              {commande.idCommandeApk ? (
                <span
                  className="inline-flex items-center gap-1 rounded-full bg-brand/10 dark:bg-accent/10 px-2.5 py-1 text-xs font-medium text-brand"
                  title="Commande saisie sur l'application mobile"
                >
                  <Smartphone size={12} />
                  Mobile
                </span>
              ) : null}
            </div>
            <p className="mt-0.5 text-sm capitalize text-neutral-500">
              {commande.dateCommande ? DATE_FMT.format(new Date(commande.dateCommande)) : 'Date inconnue'}
              {commande.idRepr ? (
                <span className="normal-case">
                  {' '}· représentant <span className="font-mono">{commande.idRepr}</span>
                </span>
              ) : null}
            </p>
          </div>
        </div>

        <div className="rounded-xl bg-white px-4 py-2 text-right shadow-card">
          <p className="text-xs text-neutral-400">Total commande</p>
          <p className="text-lg font-bold dark:text-accent">{EUR.format(commande.total)}</p>
        </div>
      </div>

      {/* Client */}
      <div className="rounded-2xl bg-white shadow-card px-5 py-3.5">
        <div className="flex flex-wrap items-center gap-2">
          <Store size={16} className="text-brand" />
          {commande.client ? (
            <Link href={`/clients/${commande.client.id}`} className="font-medium text-brand hover:underline dark:text-accent">
              {commande.client.enseigne}
              <span className="ml-1.5 font-mono text-xs text-neutral-400">{commande.client.codeAs400}</span>
            </Link>
          ) : (
            <span className="font-medium">{commande.raisonSocialeCmd ?? 'Client inconnu'}</span>
          )}
          {commande.client?.ville ? <span className="text-sm text-neutral-400">· {commande.client.ville}</span> : null}
        </div>
      </div>

      {/* Suivi de livraison */}
      {!commande.annulee ? (
        <section className="rounded-2xl bg-white shadow-card">
          <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
            <Truck size={17} className="text-brand" />
            Livraison
            <LivraisonBadge statut={commande.statutLivraison} />
          </h2>
          <div className="flex flex-col gap-4 px-5 py-4">
            <div className="flex flex-wrap gap-x-8 gap-y-1.5 text-sm">
              <span className="text-neutral-500">
                Expédiée : <span className="font-medium text-neutral-800 dark:text-neutral-100">{commande.dateExpedition ? DATE_COURT.format(new Date(commande.dateExpedition)) : '—'}</span>
              </span>
              <span className="text-neutral-500">
                Livrée : <span className="font-medium text-neutral-800 dark:text-neutral-100">{commande.dateLivraison ? DATE_COURT.format(new Date(commande.dateLivraison)) : '—'}</span>
              </span>
              {commande.transporteur ? (
                <span className="text-neutral-500">
                  Transporteur : <span className="font-medium text-neutral-800 dark:text-neutral-100">{commande.transporteur}</span>
                </span>
              ) : null}
              {commande.noSuivi ? (
                <span className="text-neutral-500">
                  Suivi : <span className="font-mono text-xs font-medium text-neutral-800 dark:text-neutral-100">{commande.noSuivi}</span>
                </span>
              ) : null}
            </div>
            {commande.commentaireLivraison && !peutEditerLivraison ? (
              <p className="text-sm text-neutral-500">{commande.commentaireLivraison}</p>
            ) : null}
            {peutEditerLivraison ? (
              <LivraisonEditor
                commandeId={commande.id}
                statut={commande.statutLivraison}
                transporteur={commande.transporteur}
                noSuivi={commande.noSuivi}
                commentaire={commande.commentaireLivraison}
              />
            ) : null}
          </div>
        </section>
      ) : null}

      {/* Lignes */}
      <section className="rounded-2xl bg-white shadow-card">
        <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
          <ShoppingCart size={17} className="text-brand" />
          Lignes
          <span className="rounded-full bg-brand/10 dark:bg-accent/10 px-2 py-0.5 text-xs font-semibold text-brand dark:text-accent">
            {commande.lignes.length}
          </span>
        </h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs text-neutral-400">
              <tr className="border-b border-neutral-100 dark:border-navy-700">
                <th className="px-5 py-2 font-medium">#</th>
                <th className="px-2 py-2 font-medium">Article</th>
                <th className="px-2 py-2 text-right font-medium">Quantité</th>
                <th className="px-5 py-2 text-right font-medium">Montant</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
              {commande.lignes.map((l) => (
                <tr key={l.id}>
                  <td className="px-5 py-2.5 font-mono text-xs text-neutral-400">{l.noLigne}</td>
                  <td className="px-2 py-2.5">
                    {l.article ? (
                      <span>
                        {l.article.libelle}
                        <span className="ml-1.5 font-mono text-xs text-neutral-400">{l.article.codeAs400}</span>
                      </span>
                    ) : (
                      <span className="text-neutral-500">{l.libelleArticle ?? '—'}</span>
                    )}
                  </td>
                  <td className="px-2 py-2.5 text-right text-neutral-500">{QTE.format(Number(l.quantite))}</td>
                  <td className="px-5 py-2.5 text-right font-medium dark:text-accent">{EUR.format(Number(l.montant))}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t border-neutral-200 dark:border-navy-700">
                <td colSpan={3} className="px-5 py-2.5 text-right text-xs font-medium uppercase tracking-wide text-neutral-400">
                  Total
                </td>
                <td className="px-5 py-2.5 text-right text-base font-bold dark:text-accent">{EUR.format(commande.total)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>
    </div>
  );
}
