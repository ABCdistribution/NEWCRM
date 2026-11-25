import type { ReactNode } from 'react';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, BadgePercent, Barcode, Boxes, Euro, FileText, Info, Sparkles } from 'lucide-react';
import { getArticle, type ArticleDetail } from '@/lib/api';
import { requireRole, TOUS_ROLES } from '@/lib/roles';
import {
  VIDE,
  etatStock,
  formaterMontant,
  formaterNombre,
  hrefProduit,
  lignesInformations,
  periodePromo,
  texteOuTiret,
} from '@/lib/produit-fiche';
import { ActiveBadge } from '@/components/badges';
import { CodeBarres } from '@/components/code-barres';

export const metadata = { title: 'Fiche produit' };

const card = 'rounded-2xl bg-white shadow-card';
const cardHeader = 'flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold';
const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

/** Pastille de l'en-tête : couleurs sémantiques de statut seulement. */
function Pastille({ className, children }: { className: string; children: ReactNode }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${className}`}>{children}</span>
  );
}

/** Texte libre de la fiche (détails, avantages) : rendu en texte, retours à la ligne conservés. */
function CarteTexte({ titre, icone: Icone, texte }: { titre: string; icone: typeof FileText; texte: string }) {
  return (
    <section className={card}>
      <h2 className={cardHeader}>
        <Icone size={17} className="text-brand" aria-hidden />
        {titre}
      </h2>
      <p className="whitespace-pre-line break-words px-5 py-4 text-sm">{texte}</p>
    </section>
  );
}

function InformationsGenerales({ article }: { article: ArticleDetail }) {
  return (
    <section className={card}>
      <h2 className={cardHeader}>
        <Info size={17} className="text-brand" aria-hidden />
        Informations générales
      </h2>
      <dl className="grid grid-cols-1 gap-x-6 gap-y-3 px-5 py-4 sm:grid-cols-2">
        {lignesInformations(article).map((l) => (
          <div key={l.label} className={l.large ? 'sm:col-span-2' : undefined}>
            <dt className="text-xs text-neutral-400">{l.label}</dt>
            <dd className={l.mono ? 'break-words font-mono text-sm tabular-nums' : 'break-words text-sm'}>{l.valeur}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

function StockEtRemplacement({ article }: { article: ArticleDetail }) {
  const etat = etatStock(article.stock, article.pcb);
  return (
    <section className={card}>
      <h2 className={cardHeader}>
        <Boxes size={17} className="text-brand" aria-hidden />
        Stock et remplacement
      </h2>
      <div className="flex flex-col gap-4 px-5 py-4">
        <div>
          <p className="text-xs text-neutral-400">Stock disponible</p>
          <p className="mt-0.5 flex flex-wrap items-baseline gap-x-3 gap-y-1">
            <span className={`text-3xl font-bold tabular-nums ${etat.tone}`}>{formaterNombre(article.stock)}</span>
            <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${etat.pastille}`}>{etat.label}</span>
          </p>
        </div>

        {article.remplacements.length === 0 ? (
          <p className="text-sm text-neutral-500">Aucun produit de remplacement</p>
        ) : (
          article.remplacements.map((r, i) => {
            const etatRemplacant = etatStock(r.article.stock, null);
            return (
              <div key={`${r.article.id}-${i}`} className="rounded-xl border border-neutral-200 p-4">
                <h3 className="text-xs font-semibold uppercase tracking-wide text-neutral-500">Produit de remplacement</h3>
                {/* Le seuil appartient à la règle (produit courant → remplaçant), pas au stock du remplaçant. */}
                <dl className="mt-1 flex flex-wrap items-baseline gap-x-2 text-xs">
                  <dt className="text-neutral-400">Seuil de la règle</dt>
                  <dd className="text-sm font-medium tabular-nums">{formaterNombre(r.seuil)}</dd>
                </dl>
                <p className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1">
                  <Link
                    href={hrefProduit(r.article.id)}
                    className={`break-words font-semibold text-brand hover:underline ${FOCUS}`}
                  >
                    {r.article.libelle}
                  </Link>
                  {r.article.actif ? null : <ActiveBadge active={false} />}
                </p>
                <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2">
                  <div>
                    <dt className="text-xs text-neutral-400">Code</dt>
                    <dd className="font-mono text-sm tabular-nums">{r.article.codeAs400}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-neutral-400">Marque</dt>
                    <dd className="break-words text-sm">{texteOuTiret(r.article.marque?.nom)}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-neutral-400">Stock disponible</dt>
                    <dd className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
                      <span className={`font-semibold tabular-nums ${etatRemplacant.tone}`}>{formaterNombre(r.article.stock)}</span>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${etatRemplacant.pastille}`}>
                        {etatRemplacant.label}
                      </span>
                    </dd>
                  </div>
                </dl>
              </div>
            );
          })
        )}
      </div>
    </section>
  );
}

function Tarifs({ article }: { article: ArticleDetail }) {
  return (
    <section className={card}>
      <h2 className={cardHeader}>
        <Euro size={17} className="text-brand" aria-hidden />
        Tarifs
      </h2>
      {article.tarifs.length === 0 ? (
        <p className="px-5 py-4 text-sm">
          <span aria-hidden="true">{VIDE}</span>
          <span className="sr-only">Aucun tarif</span>
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">Tarifs du produit</caption>
            <thead className="text-left text-xs text-neutral-400">
              <tr className="border-b border-neutral-100">
                <th scope="col" className="px-5 py-2 font-medium">Code tarif</th>
                <th scope="col" className="px-5 py-2 text-right font-medium">Montant</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {article.tarifs.map((t, i) => (
                <tr key={`${t.codeTarif ?? 'sans-code'}-${i}`}>
                  <td className="px-5 py-2.5 font-mono text-xs">{texteOuTiret(t.codeTarif)}</td>
                  <td className="px-5 py-2.5 text-right font-medium tabular-nums">{formaterMontant(t.montant)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

export default async function ProduitFiche({ params }: { params: Promise<{ id: string }> }) {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;

  const { id } = await params;
  // getArticle valide l'UUID (idSur → 404) ; l'API tranche l'existence et l'accès (404 / 403 → page introuvable).
  const article = await getArticle(id);
  if (!article) notFound();

  const details = article.details?.trim();
  const avantages = article.avantages?.trim();

  return (
    <div className="flex flex-col gap-5">
      {/* En-tête */}
      <div className="flex items-start gap-3">
        <Link
          href="/produits"
          className={`mt-1 shrink-0 rounded-lg p-2 text-neutral-500 transition hover:bg-neutral-100 hover:text-neutral-700 ${FOCUS}`}
          aria-label="Retour aux produits"
        >
          <ArrowLeft size={18} aria-hidden />
        </Link>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="break-words text-2xl font-bold">{article.libelle}</h1>
            <ActiveBadge active={article.actif} />
            {article.enPromo ? <Pastille className="bg-positif/15 text-emerald-800">Promo</Pastille> : null}
            {article.misEnAvant ? <Pastille className="bg-badge text-navy">Mis en avant</Pastille> : null}
            {article.retourAutorise ? <Pastille className="bg-amber-500/15 text-amber-800">Retour autorisé</Pastille> : null}
          </div>
          <p className="mt-0.5 text-sm text-neutral-500">
            <span className="font-mono text-xs">{article.codeAs400}</span>
            {article.marque?.nom ? (
              <>
                <span className="mx-1.5 text-neutral-300" aria-hidden="true">·</span>
                {article.marque.nom}
              </>
            ) : null}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <div className="flex min-w-0 flex-col gap-5 xl:col-span-2">
          <InformationsGenerales article={article} />
          {details ? <CarteTexte titre="Détails" icone={FileText} texte={details} /> : null}
          {avantages ? <CarteTexte titre="Avantages" icone={Sparkles} texte={avantages} /> : null}
        </div>

        <div className="flex min-w-0 flex-col gap-5">
          <StockEtRemplacement article={article} />

          <section className={card}>
            <h2 className={cardHeader}>
              <Barcode size={17} className="text-brand" aria-hidden />
              Code-barres
            </h2>
            <div className="px-5 py-4">
              <CodeBarres gencode={article.gencode} />
            </div>
          </section>

          <Tarifs article={article} />

          {article.promos.length > 0 ? (
            <section className={card}>
              <h2 className={cardHeader}>
                <BadgePercent size={17} className="text-brand" aria-hidden />
                Promotions en cours
              </h2>
              <ul className="divide-y divide-neutral-100">
                {article.promos.map((p, i) => (
                  <li key={i} className="px-5 py-3">
                    <p className="break-words text-sm font-medium">{p.libelle?.trim() || 'Promotion'}</p>
                    <p className="text-xs text-neutral-500">{periodePromo(p.dateDebut, p.dateFin)}</p>
                  </li>
                ))}
              </ul>
            </section>
          ) : null}
        </div>
      </div>
    </div>
  );
}
