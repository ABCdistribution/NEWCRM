import { notFound } from 'next/navigation';
import { requireRole, type Role } from '@/lib/roles';
import { getRapportDetail, listPlanningMembre } from '@/lib/api';
import { commandesDe, lignesPromoteurs, listerUtilisateurs, visitesDe } from '@/lib/equipe';
import { ajouterJours, chefDe, estUuid, iso, lundiDemande, zoneDe } from '@/lib/equipe-utils';
import { NavSemaine, Onglets, ListePromoteurs } from '@/components/equipe-ui';
import { CarteRapport, ListeCommandes, ListeVisites, PlanningCs } from '@/components/equipe-fiche';
import { FicheEntete } from '@/components/fiche-entete';

export const metadata = { title: "Fiche chef de secteur — Direction commerciale" };

// Fiche d'un chef de secteur, vue par son directeur régional (ADMIN : vue technique).
const ROLES_AUTORISES: readonly Role[] = ['DIRECTEUR_REGIONAL', 'ADMIN'];
const ONGLETS = [
  { id: 'planning', label: 'Planning' },
  { id: 'visites', label: 'Visites' },
  { id: 'commandes', label: 'Commandes' },
  { id: 'promoteurs', label: 'Promoteurs' },
];
const JOUR_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });

export default async function FicheChefSecteurPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ onglet?: string; semaine?: string }>;
}) {
  const acces = await requireRole(ROLES_AUTORISES);
  if (acces.refuse) return acces.refuse;

  const { id } = await params;
  const sp = await searchParams;
  if (!estUuid(id)) notFound();

  // L'API ne renvoie que les utilisateurs de mon périmètre : un id hors périmètre donne une page introuvable.
  const users = await listerUtilisateurs();
  const cs = users?.find((u) => u.id === id && u.role === 'CHEF_SECTEUR');
  if (!users || !cs) notFound();

  const onglet = ONGLETS.some((o) => o.id === sp.onglet) ? sp.onglet! : 'planning';
  const base = `/mon-equipe/${cs.id}`;
  const lundi = lundiDemande(sp.semaine);
  const semaineLibelle = `Semaine du ${JOUR_FMT.format(lundi)} au ${JOUR_FMT.format(ajouterJours(lundi, 4))}`;

  let contenu: React.ReactNode;
  if (onglet === 'planning') {
    const [planning, rapport] = await Promise.all([
      listPlanningMembre(cs.id, iso(lundi), iso(ajouterJours(lundi, 7))),
      getRapportDetail(cs.id, iso(lundi)),
    ]);
    contenu = (
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-sm text-neutral-500">Planning en lecture seule.</p>
          <NavSemaine
            libelle={semaineLibelle}
            hrefPrec={`${base}?onglet=planning&semaine=${iso(ajouterJours(lundi, -7))}`}
            hrefSuiv={`${base}?onglet=planning&semaine=${iso(ajouterJours(lundi, 7))}`}
          />
        </div>
        {planning ? (
          <PlanningCs lundi={lundi} etapes={planning.etapes} />
        ) : (
          <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            Planning indisponible pour cette semaine.
          </p>
        )}
        <CarteRapport rapport={rapport} semaineLibelle={semaineLibelle} />
      </div>
    );
  } else if (onglet === 'visites') {
    const r = await visitesDe(cs.id);
    contenu = <ListeVisites visites={r?.lignes ?? null} tronque={r?.tronque ?? false} titre={`Visites de ${cs.displayName}`} />;
  } else if (onglet === 'commandes') {
    const r = await commandesDe(cs.idRepr);
    contenu = (
      <div className="flex flex-col gap-3">
        {!cs.idRepr ? <p className="text-sm text-neutral-500">Ce chef de secteur n&apos;a pas de code représentant : aucune commande ne lui est rattachée.</p> : null}
        <ListeCommandes commandes={r?.lignes ?? null} tronque={r?.tronque ?? false} titre={`Commandes de ${cs.displayName}`} />
      </div>
    );
  } else {
    const chefs = users.filter((u) => u.role === 'CHEF_SECTEUR');
    const equipe = users.filter((u) => u.role === 'COMMERCIAL' && u.isActive && chefDe(u, chefs)?.id === cs.id);
    const promos = (await lignesPromoteurs(equipe, chefs)).sort((a, b) => a.nom.localeCompare(b.nom));
    contenu = (
      <div className="flex flex-col gap-3">
        <p className="text-sm text-neutral-500">{promos.length} promoteur{promos.length > 1 ? 's' : ''} · {zoneDe(cs)}</p>
        <ListePromoteurs promos={promos} vide="Aucun promoteur rattaché à ce chef de secteur." />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <FicheEntete
        nom={cs.displayName}
        sousTitre={`Chef de secteur · ${zoneDe(cs)}`}
        retourHref="/mon-equipe"
        retourLabel="Retour à Mon équipe"
        email={cs.email}
      />
      <Onglets onglets={ONGLETS} actif={onglet} hrefDe={(o) => `${base}?onglet=${o}`} label="Sections de la fiche" />
      <div role="tabpanel">{contenu}</div>
    </div>
  );
}
