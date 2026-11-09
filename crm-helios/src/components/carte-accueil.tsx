import { qs, serverFetch, type ClientRow, type Paginated } from '@/lib/api';
import { getCarteEquipes, getCarteSecteur } from '@/lib/carte';
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

/** Clients du secteur via l'endpoint déjà utilisé par le site (repli quand rien n'est géolocalisé). */
async function clientsRepli(): Promise<{ lignes: ClientRow[] | null; erreur: string | null }> {
  try {
    const res = await serverFetch(`/clients${qs({ limit: 100 })}`);
    if (!res.ok) return { lignes: null, erreur: `Liste des clients indisponible (erreur ${res.status}).` };
    return { lignes: ((await res.json()) as Paginated<ClientRow>).data, erreur: null };
  } catch {
    return { lignes: null, erreur: "Liste des clients indisponible : l'API ne répond pas." };
  }
}

/**
 * Carte d'accueil (composant serveur). Les erreurs restent localisées : l'accueil s'affiche quand même.
 * `mode` : « equipes » (DR / ADMIN / DIRECTION) ou « secteur » (chef de secteur).
 */
export async function CarteAccueil({ mode }: { mode: 'equipes' | 'secteur' }) {
  const { deps, erreur: erreurFond } = fondDepartements();
  if (!deps) return <Erreur message={erreurFond ?? 'Fond de carte indisponible.'} />;

  if (mode === 'equipes') {
    const r = await getCarteEquipes();
    if (r.erreur !== undefined) return <Erreur message={r.erreur} />;
    return <CarteEquipes data={r.data} fond={deps} />;
  }

  const r = await getCarteSecteur();
  if (r.erreur !== undefined) return <Erreur message={r.erreur} />;
  const vide = r.data.clients.length === 0 && r.data.prospects.length === 0;
  const repli = vide ? await clientsRepli() : { lignes: null, erreur: null };
  return <CarteMonSecteur data={r.data} fond={deps} repli={repli.lignes} repliErreur={repli.erreur} />;
}

export function CarteAccueilSquelette() {
  return (
    <div
      className="h-96 animate-pulse rounded-2xl bg-white shadow-card"
      role="status"
      aria-label="Chargement de la carte"
    />
  );
}
