import type { Role } from '@/lib/api';
import { getCarteEquipes, getCarteSecteur, getClientsRepli } from '@/lib/carte';
import { peutOuvrirFicheChefSecteur, peutOuvrirFichePromoteur } from '@/lib/carte-fiches';
import { fondDepartements } from '@/lib/carte-fond';
import { CarteEquipes } from './carte-equipes';
import { CarteMonSecteur } from './carte-mon-secteur';

function Erreur({ message }: { message: string }) {
  return (
    <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800" role="alert">
      {message}
    </p>
  );
}

/**
 * Carte d'accueil (composant serveur). Les erreurs restent localisées : l'accueil s'affiche quand même.
 * `mode` : « equipes » (DR / ADMIN / DIRECTION) ou « secteur » (chef de secteur).
 * `role` : rôle de l'utilisateur ; il ne sert qu'à décider quels noms de la carte des équipes deviennent des
 * liens vers une fiche (DIRECTION n'en ouvre aucune), jamais à filtrer des données.
 * Les données viennent de /dashboard/carte-equipes et /dashboard/carte-secteur, que l'API filtre par rôle et périmètre.
 */
export async function CarteAccueil({
  mode,
  role,
  annee,
  mois,
  moiId,
}: {
  mode: 'equipes' | 'secteur';
  role: Role;
  /** Identifiant de l'utilisateur connecté (non relisté dans la direction de sa région). */
  moiId?: string;
  /** Mois de l'activité de la carte des équipes (sélecteur de mois de l'accueil). */
  annee?: number;
  mois?: number;
}) {
  // Carte des équipes : formes des régions embarquées (même carte que l'annuaire), aucun fond de départements.
  if (mode === 'equipes') {
    const r = await getCarteEquipes({ annee, mois });
    if (r.erreur !== undefined) return <Erreur message={r.erreur} />;
    return (
      <CarteEquipes
        data={r.data}
        ficheChefSecteur={peutOuvrirFicheChefSecteur(role)}
        fichePromoteur={peutOuvrirFichePromoteur(role)}
        // Directeur régional : une ou deux régions, pas de carte de France ; ses équipes s'affichent directement.
        sansCarte={role === 'DIRECTEUR_REGIONAL'}
        moiId={moiId}
      />
    );
  }

  // Carte du secteur : points sur le fond de départements.
  const { deps, erreur: erreurFond } = fondDepartements();
  if (!deps) return <Erreur message={erreurFond ?? 'Fond de carte indisponible.'} />;
  const r = await getCarteSecteur();
  if (r.erreur !== undefined) return <Erreur message={r.erreur} />;
  const vide = r.data.clients.length === 0 && r.data.prospects.length === 0;
  // Repli : quand rien n'est géolocalisé, on liste les clients du périmètre (voir getClientsRepli).
  const repli = vide ? await getClientsRepli() : null;
  return <CarteMonSecteur data={r.data} fond={deps} repli={repli?.data ?? null} repliErreur={repli?.erreur ?? null} />;
}

export function CarteAccueilSquelette() {
  return (
    <div
      className="h-96 rounded-2xl bg-white shadow-card motion-safe:animate-pulse"
      role="status"
      aria-label="Chargement de la carte"
    />
  );
}
