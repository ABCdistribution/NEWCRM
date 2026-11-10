import { Suspense } from 'react';
import Link from 'next/link';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { getDashboardDirection, type Me } from '@/lib/api';
import { aujourdhuiParis } from '@/lib/planning-dates';
import { DashboardCS } from '@/components/dashboard-cs';
import { CarteAccueil, CarteAccueilSquelette } from '@/components/carte-accueil';

const MOIS_LABELS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const FOCUS =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';

/**
 * La période arrive d'une URL (?annee=&mois=), donc d'une saisie libre : on la ramène à des bornes sûres
 * (année entière entre 2000 et 2100, mois entre 1 et 12), sinon le mois courant. L'API rebornerait le mois
 * mais accepterait n'importe quelle année.
 */
function periodeSure(annee: number, mois: number): { annee: number; mois: number } {
  // Mois courant À PARIS (fuseau de l'API), pas celui du serveur Next.
  const maintenant = aujourdhuiParis();
  return {
    annee: Number.isInteger(annee) && annee >= 2000 && annee <= 2100 ? annee : maintenant.getFullYear(),
    mois: Number.isInteger(mois) && mois >= 1 && mois <= 12 ? mois : maintenant.getMonth() + 1,
  };
}

/**
 * Accueil « direction » (ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR) : composant serveur. Le chef de secteur
 * voit « Mon secteur » (DashboardCS, carte en mode points) ; les autres rôles ne voient que la carte des équipes
 * (carte, secteurs avec leur CA du mois, équipes d'une région) : plus de tuiles, de graphiques ni de classement.
 * La carte des équipes suit le mois du sélecteur. Les chiffres viennent de l'API, qui les filtre par rôle et
 * périmètre : ce composant n'applique aucun filtre. L'appelant (la page d'accueil) vérifie le rôle et fournit `me`.
 *
 * Trou connu côté API (à corriger dans crm-api, rien n'est compensé ici) : pour CHEF_SECTEUR, le bloc prospection et le
 * nuage objectif / CA (scatterMagasins) de /dashboard/direction couvrent le réseau entier.
 */
export async function DashboardDirection({
  me,
  annee: anneeDemandee,
  mois: moisDemande,
}: {
  me: Me;
  annee: number;
  mois: number;
}) {
  const { annee, mois } = periodeSure(anneeDemandee, moisDemande);

  const prev = mois === 1 ? { annee: annee - 1, mois: 12 } : { annee, mois: mois - 1 };
  const next = mois === 12 ? { annee: annee + 1, mois: 1 } : { annee, mois: mois + 1 };

  const isCS = me.role === 'CHEF_SECTEUR';
  // Seul « Mon secteur » a besoin de /dashboard/direction ; la carte des équipes a ses propres données.
  const data = isCS ? await getDashboardDirection(annee, mois) : null;
  const prenom = me.displayName.split(/\s+/)[0] ?? '';
  const carteMode: 'equipes' | 'secteur' | null = isCS
    ? 'secteur'
    : me.role === 'ADMIN' || me.role === 'DIRECTION' || me.role === 'DIRECTEUR_REGIONAL'
      ? 'equipes'
      : null;

  return (
    <div className="flex flex-col gap-5">
      {/* Accueil de l'encadrement hors chef de secteur : aucun en-tête (ni titre, ni bienvenue, ni mois) ; le titre reste
          pour les lecteurs d'écran. Le chef de secteur garde « Mon secteur » et son sélecteur de mois. */}
      {!isCS ? <h1 className="sr-only">Pilotage force de vente</h1> : null}
      {isCS ? (
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Mon secteur</h1>
          <p className="text-sm text-neutral-500">
            Bonjour {prenom} — {data?.scope.label.toLowerCase() ?? 'vue globale'}.
          </p>
        </div>

        {/* Sélecteur de mois */}
        <nav aria-label="Choix du mois" className="flex items-center gap-1 rounded-xl bg-white p-1 shadow-card">
          <Link
            href={`/?annee=${prev.annee}&mois=${prev.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label={`Mois précédent : ${MOIS_LABELS[prev.mois - 1]} ${prev.annee}`}
          >
            <ChevronLeft size={16} aria-hidden />
          </Link>
          <span className="min-w-36 text-center text-sm font-medium">
            {MOIS_LABELS[mois - 1]} {annee}
          </span>
          <Link
            href={`/?annee=${next.annee}&mois=${next.mois}`}
            className={`rounded-lg p-1.5 text-neutral-500 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${FOCUS}`}
            aria-label={`Mois suivant : ${MOIS_LABELS[next.mois - 1]} ${next.annee}`}
          >
            <ChevronRight size={16} aria-hidden />
          </Link>
        </nav>
      </div>
      ) : null}

      {/* Carte en haut de l'accueil ; ne bloque pas le reste de la page (Suspense + erreurs localisées). */}
      {carteMode ? (
        <Suspense fallback={<CarteAccueilSquelette />}>
          <CarteAccueil mode={carteMode} role={me.role} annee={annee} mois={mois} moiId={me.id} />
        </Suspense>
      ) : null}

      {isCS ? (
        data ? (
          <DashboardCS data={data} />
        ) : (
          <p
            className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
            role="alert"
          >
            Chiffres indisponibles — l&apos;API est-elle démarrée ?
          </p>
        )
      ) : null}
    </div>
  );
}
