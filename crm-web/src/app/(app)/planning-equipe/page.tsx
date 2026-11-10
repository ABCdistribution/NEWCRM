import Link from 'next/link';
import { CalendarCog } from 'lucide-react';
import { listPlannings, listRegles } from '@/lib/api';
import { clientsDuPromoteur, listerUtilisateurs } from '@/lib/equipe';
import { ajouterJours, estUuid, iso, lundiDemande, zoneDe } from '@/lib/equipe-utils';
import { ENCADREMENT, requireRole } from '@/lib/roles';
import { ROUTES } from '@/lib/routes';
import { CARTE, NavSemaine } from '@/components/equipe-ui';
import { PlanningEquipeBoard, SelecteurPromoteur, type JourPlanning } from '@/components/planning-equipe-board';
import { RecurrenceCard } from '@/components/recurrence-card';

export const metadata = { title: "Planning de l'équipe" };

const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
const JOUR_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long' });
const JOUR_COURT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short' });

/**
 * Planning de l'équipe (ADMIN, DIRECTION, DR, CS) : visites jour par jour chez les clients, règles de
 * récurrence, relance des visites manquées. Le périmètre est appliqué par l'API (liste des promoteurs
 * et accès au planning) ; l'heure et la consigne d'une visite ne sont pas gérées par l'API.
 */
export default async function PlanningEquipePage({ searchParams }: { searchParams: Promise<{ promoteur?: string; semaine?: string }> }) {
  const acces = await requireRole(ENCADREMENT);
  if (acces.refuse) return acces.refuse;

  // Les fiches « Mon équipe » excluent DIRECTION : on n'affiche le lien (table des routes) qu'aux rôles qui y entrent.
  const peutVoirFiche = ROUTES.find((r) => r.href === '/mon-equipe')?.roles.includes(acces.me.role) ?? false;

  const sp = await searchParams;
  const users = await listerUtilisateurs();
  const promoteurs = (users ?? [])
    .filter((u) => u.role === 'COMMERCIAL' && u.isActive)
    .sort((a, b) => a.displayName.localeCompare(b.displayName));

  const lundi = lundiDemande(sp.semaine);
  const semaine = iso(lundi);
  const semaineLibelle = `Semaine du ${JOUR_FMT.format(lundi)} au ${JOUR_FMT.format(ajouterJours(lundi, 4))}`;

  // L'id demandé doit appartenir à ma liste (déjà filtrée par périmètre) ; sinon on retombe sur le premier promoteur.
  const promo = (estUuid(sp.promoteur) ? promoteurs.find((p) => p.id === sp.promoteur) : null) ?? promoteurs[0] ?? null;

  let contenu: React.ReactNode;
  if (!users) {
    contenu = (
      <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Liste des promoteurs indisponible : réessayez dans un instant.
      </p>
    );
  } else if (!promo) {
    contenu = <p className={`${CARTE} px-5 py-8 text-center text-sm text-neutral-500`}>Aucun promoteur dans votre équipe.</p>;
  } else {
    const [visites, clients, regles] = await Promise.all([
      listPlannings(promo.id, semaine, iso(ajouterJours(lundi, 7))),
      clientsDuPromoteur(promo.idRepr),
      listRegles(promo.id),
    ]);
    const jours: JourPlanning[] = JOURS.map((nom, i) => {
      const d = ajouterJours(lundi, i);
      const date = iso(d);
      return {
        nom,
        libelle: JOUR_COURT.format(d),
        date,
        visites: (visites ?? [])
          .filter((v) => v.datePassage.slice(0, 10) === date)
          .map((v) => ({
            id: v.id,
            clientId: v.client.id,
            clientNom: v.client.enseigne.trim(),
            ville: v.client.ville,
            classe: v.client.niveauClass,
            fait: v.fait,
            recurrente: !!v.plannificationId,
          })),
      };
    });
    const base = `/planning-equipe?promoteur=${encodeURIComponent(promo.id)}`;
    contenu = (
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <SelecteurPromoteur promoteurs={promoteurs.map((p) => ({ id: p.id, nom: p.displayName }))} valeur={promo.id} semaine={semaine} />
          <NavSemaine
            libelle={semaineLibelle}
            hrefPrec={`${base}&semaine=${iso(ajouterJours(lundi, -7))}`}
            hrefSuiv={`${base}&semaine=${iso(ajouterJours(lundi, 7))}`}
          />
        </div>
        <p className="text-sm text-neutral-500">
          {promo.displayName} · {zoneDe(promo)}
          {peutVoirFiche ? (
            <>
              {' · '}
              <Link href={`/mon-equipe/promoteur/${encodeURIComponent(promo.id)}`} className="font-medium text-brand underline-offset-2 hover:underline dark:text-accent">
                Voir la fiche
              </Link>
            </>
          ) : null}
        </p>
        {visites === null ? (
          <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            Planning indisponible pour cette semaine : l&apos;ajout reste possible mais la liste n&apos;est pas à jour.
          </p>
        ) : null}
        {clients.length === 0 ? (
          <p className="text-sm text-neutral-500">Ce promoteur n&apos;a pas de clients rattachés (code représentant absent ou portefeuille vide) : aucune visite ne peut être ajoutée.</p>
        ) : null}
        {regles === null ? (
          <p role="alert" className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
            Règles de récurrence indisponibles pour ce promoteur.
          </p>
        ) : (
          <RecurrenceCard
            promoteurId={promo.id}
            semaineIso={semaine}
            regles={regles}
            portefeuille={clients.map((c) => ({ id: c.id, enseigne: c.enseigne, ville: c.ville, niveauClass: c.niveauClass }))}
          />
        )}
        <PlanningEquipeBoard
          promoteurId={promo.id}
          jours={jours}
          clients={clients.map((c) => ({ id: c.id, enseigne: c.enseigne, ville: c.ville, codeAs400: c.codeAs400 }))}
        />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <header>
        <h1 className="flex items-center gap-2 text-2xl font-bold">
          <CalendarCog size={22} className="text-brand dark:text-accent" aria-hidden /> Planning de l&apos;équipe
        </h1>
        <p className="mt-1 text-sm text-neutral-500">
          Planifiez, déplacez ou retirez les visites de vos promoteurs chez leurs clients, et gérez leurs récurrences.
        </p>
      </header>
      {contenu}
    </div>
  );
}
