import { notFound } from 'next/navigation';
import { Pencil } from 'lucide-react';
import { listPlannings } from '@/lib/api';
import { requireRole, type Role } from '@/lib/roles';
import { clientsDuPromoteur, commandesDe, lignesPromoteurs, listerUtilisateurs, visitesDe } from '@/lib/equipe';
import { ajouterJours, estUuid, iso, lundiDemande, zoneDe } from '@/lib/equipe-utils';
import { AvertissementIncomplet, CaObjectif, CARTE, NavSemaine, Onglets } from '@/components/equipe-ui';
import { ListeCommandes, ListeVisites, PlanningPromoteur } from '@/components/equipe-fiche';
import { FicheEntete } from '@/components/fiche-entete';
import { SelecteurClient } from '@/components/selecteur-client';
import Link from 'next/link';

export const metadata = { title: 'Fiche promoteur — Direction commerciale' };

// Chef de secteur, directeur régional, ADMIN (le périmètre est filtré par l'API : id hors périmètre → 404).
const ROLES_AUTORISES: readonly Role[] = ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN'];
const ONGLETS = [
  { id: 'planning', label: 'Planning' },
  { id: 'visites', label: 'Visites' },
  { id: 'commandes', label: 'Commandes' },
];
const JOUR_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

export default async function FichePromoteurPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ onglet?: string; semaine?: string; client?: string }>;
}) {
  const acces = await requireRole(ROLES_AUTORISES);
  if (acces.refuse) return acces.refuse;

  const { id } = await params;
  const sp = await searchParams;
  if (!estUuid(id)) notFound();

  // L'API ne renvoie que les utilisateurs de mon périmètre : un id hors périmètre donne une page introuvable.
  const users = await listerUtilisateurs();
  const promo = users?.find((u) => u.id === id && u.role === 'COMMERCIAL');
  if (!users || !promo) notFound();

  const chefs = users.filter((u) => u.role === 'CHEF_SECTEUR');
  const [ligne] = await lignesPromoteurs([promo], chefs);
  const onglet = ONGLETS.some((o) => o.id === sp.onglet) ? sp.onglet! : 'planning';
  const base = `/mon-equipe/promoteur/${promo.id}`;
  const lundi = lundiDemande(sp.semaine);
  const semaineLibelle = `Semaine du ${JOUR_FMT.format(lundi)} au ${JOUR_FMT.format(ajouterJours(lundi, 4))}`;

  let contenu: React.ReactNode;
  if (onglet === 'planning') {
    const visites = await listPlannings(promo.id, iso(lundi), iso(ajouterJours(lundi, 7)));
    contenu = (
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-neutral-500">Vous pouvez modifier ce planning (visites chez un client) depuis « Planning de l&apos;équipe ».</p>
          <NavSemaine
            libelle={semaineLibelle}
            hrefPrec={`${base}?onglet=planning&semaine=${iso(ajouterJours(lundi, -7))}`}
            hrefSuiv={`${base}?onglet=planning&semaine=${iso(ajouterJours(lundi, 7))}`}
          />
        </div>
        {visites ? (
          <PlanningPromoteur lundi={lundi} visites={visites} />
        ) : (
          <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            Planning indisponible pour cette semaine.
          </p>
        )}
        <div>
          <Link
            href={`/planning-equipe?promoteur=${encodeURIComponent(promo.id)}&semaine=${iso(lundi)}`}
            className="inline-flex items-center gap-1.5 rounded-lg bg-brand px-4 py-2.5 text-sm font-medium text-white transition hover:opacity-90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          >
            <Pencil size={15} aria-hidden /> Modifier le planning
          </Link>
        </div>
      </div>
    );
  } else {
    const clients = await clientsDuPromoteur(promo.idRepr);
    const choisi = estUuid(sp.client) ? clients.find((c) => c.id === sp.client) ?? null : null;
    const titre = choisi ? `${choisi.enseigne}` : 'Tous les clients';
    const liste =
      onglet === 'visites' ? (
        await visitesDe(promo.id, choisi).then((r) => <ListeVisites visites={r?.lignes ?? null} tronque={r?.tronque ?? false} titre={`Visites · ${titre}`} />)
      ) : (
        await commandesDe(promo.idRepr, choisi).then((r) => <ListeCommandes commandes={r?.lignes ?? null} tronque={r?.tronque ?? false} titre={`Commandes · ${titre}`} />)
      );
    contenu = (
      <div className="flex flex-col gap-4">
        <SelecteurClient clients={clients} valeur={choisi?.id ?? 'tous'} base={`${base}?onglet=${onglet}`} />
        {liste}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <FicheEntete
        nom={promo.displayName}
        sousTitre={`Promoteur · ${ligne.nbClients != null ? `${ligne.nbClients} client${ligne.nbClients > 1 ? 's' : ''} · ` : ''}${zoneDe(promo)}${ligne.csNom ? ` · ${ligne.csNom}` : ''}`}
        retourHref="/mon-equipe"
        retourLabel="Retour à Mon équipe"
        email={promo.email}
      />
      <AvertissementIncomplet actif={ligne.incomplet} />
      <section className={`${CARTE} grid grid-cols-1 gap-4 p-4 sm:grid-cols-3`} aria-label="Indicateurs du promoteur">
        <div>
          <p className="text-xs text-neutral-400">Visites de la semaine</p>
          <p className="text-lg font-bold tabular-nums">{ligne.visitesPrevues != null ? `${ligne.visitesFaites}/${ligne.visitesPrevues}` : '—'}</p>
        </div>
        <div className="sm:col-span-2">
          <p className="text-xs text-neutral-400">CA du mois / objectif</p>
          <CaObjectif ca={ligne.ca} objectif={ligne.objectif} className="mt-1" />
        </div>
      </section>
      <Onglets onglets={ONGLETS} actif={onglet} hrefDe={(o) => `${base}?onglet=${o}`} label="Sections de la fiche" />
      <div role="tabpanel">{contenu}</div>
    </div>
  );
}
