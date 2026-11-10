'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, listClients, listProspects, idSur } from './api';
import { messageErreurApi } from './erreurs-api';
import { ENCADREMENT, exigerRole, messageRefus } from './roles';

const PAGE = '/planning';
const ERREUR_RESEAU = "Impossible de joindre l'API.";
const ACCES_REFUSE = 'Accès refusé : action réservée à l’encadrement.';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_ISO = /^\d{4}-\d{2}-\d{2}$/;
const HEURE = /^([01]\d|2[0-3]):[0-5]\d$/;

type Resultat = { error: string | null };

/** Cible proposée dans la recherche d'ajout : magasin existant ou prospect. */
export type CibleTournee = {
  type: 'CLIENT' | 'PROSPECT';
  id: string;
  enseigne: string;
  ville: string | null;
  niveauClass: string | null;
};

/** Qualification optionnelle d'une étape (reprise de l'outil historique). */
export type OptionsEtape = {
  heure?: string; // 'HH:MM' — fusionnée dans datePassage
  visiteSimple?: boolean;
  accompagnement?: boolean;
  rdv?: boolean;
  soireeEtape?: boolean;
  soireeLieu?: string;
  soireeAdresse?: string;
  note?: string;
  /** Client ou lieu en texte libre (ligne libre du rapport) et adresse de la ligne. */
  libelle?: string;
  adresse?: string;
};

async function controle(): Promise<string | null> {
  try {
    await exigerRole(ENCADREMENT);
    return null;
  } catch (e) {
    return messageRefus(e, ACCES_REFUSE);
  }
}

/** Jour « yyyy-mm-dd » qui existe réellement au calendrier (refuse 2026-02-31). */
function jourValide(v: string): boolean {
  if (!DATE_ISO.test(v)) return false;
  const d = new Date(`${v}T12:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
}

/** Contrôle du jour de passage et de l'heure « HH:MM » facultative ; renvoie un message d'erreur sinon. */
function erreurDateHeure(datePassage: string, heure?: string): string | null {
  if (!jourValide(datePassage)) return 'Date invalide.';
  if (heure && !HEURE.test(heure)) return 'Heure invalide (format attendu : HH:MM).';
  return null;
}

async function messageErreur(res: Response): Promise<string> {
  if (res.status === 403) return 'Accès refusé.';
  if (res.status === 404) return 'Étape introuvable (déjà supprimée ?).';
  return messageErreurApi(res, 'tournee');
}

/** Appel d'une mutation : contrôle de rôle, validation de l'id, statut HTTP, message français. */
async function muter(
  chemin: (id: string) => string,
  id: string | null,
  init: RequestInit,
): Promise<Resultat> {
  const refus = await controle();
  if (refus) return { error: refus };
  if (id !== null && !UUID.test(id)) return { error: 'Identifiant invalide.' };
  let res: Response;
  try {
    res = await serverFetch(chemin(id === null ? '' : idSur(id)), init);
  } catch {
    return { error: ERREUR_RESEAU };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  revalidatePath(PAGE);
  return { error: null };
}

const JSON_HEADERS = { 'Content-Type': 'application/json' };

/** Recherche mêlée magasins + prospects (pour la combobox d'ajout d'étape). */
export async function searchCibles(q: string): Promise<CibleTournee[]> {
  if (await controle()) return [];
  const query = q.trim();
  if (query.length < 2) return [];
  const [clients, prospects] = await Promise.all([
    listClients({ search: query, page: 1 }).catch(() => null),
    listProspects({ search: query, page: 1 }).catch(() => null),
  ]);
  return [
    ...(prospects?.data ?? []).slice(0, 5).map((p) => ({
      type: 'PROSPECT' as const,
      id: p.id,
      enseigne: p.enseigne,
      ville: p.ville,
      niveauClass: p.niveauClass,
    })),
    ...(clients?.data ?? []).slice(0, 6).map((c) => ({
      type: 'CLIENT' as const,
      id: c.id,
      enseigne: c.enseigne,
      ville: c.ville,
      niveauClass: c.niveauClass,
    })),
  ];
}

/** Ajoute une étape (prospect, magasin, ADM ou ligne libre) à MON planning. */
export async function addEtape(
  cible: { type: 'CLIENT' | 'PROSPECT' | 'ADM' | 'LIBRE'; id?: string },
  datePassage: string,
  options: OptionsEtape = {},
): Promise<Resultat> {
  if ((cible.type === 'CLIENT' || cible.type === 'PROSPECT') && !(cible.id && UUID.test(cible.id))) {
    return { error: 'Identifiant invalide.' };
  }
  const invalide = erreurDateHeure(datePassage, options.heure);
  if (invalide) return { error: invalide };
  const { heure, note, ...drapeaux } = options;
  return muter(() => '/tournees', null, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({
      datePassage: heure ? `${datePassage}T${heure}:00` : datePassage,
      ...(note?.trim() ? { note: note.trim() } : {}),
      ...drapeaux,
      ...(cible.type === 'ADM'
        ? { adm: true }
        : cible.type === 'CLIENT'
          ? { clientId: cible.id }
          : cible.type === 'PROSPECT'
            ? { prospectId: cible.id }
            : {}), // ligne libre : le libellé (client ou lieu en texte) est dans les options
    }),
  });
}

/** Coche / décoche une étape (visite faite). */
export async function toggleEtapeFaite(id: string, fait: boolean): Promise<Resultat> {
  return muter((i) => `/tournees/${i}`, id, {
    method: 'PATCH',
    headers: JSON_HEADERS,
    body: JSON.stringify({ fait }),
  });
}

/** Déplace une étape vers une autre date (drag & drop entre jours). */
export async function moveEtape(id: string, datePassage: string): Promise<Resultat> {
  if (!jourValide(datePassage)) return { error: 'Date invalide.' };
  return muter((i) => `/tournees/${i}`, id, {
    method: 'PATCH',
    headers: JSON_HEADERS,
    body: JSON.stringify({ datePassage }),
  });
}

/** Requalifie une étape existante (type de passage, RDV, soirée étape, date, note) sans la recréer. */
export async function requalifierEtape(
  id: string,
  datePassage: string,
  options: OptionsEtape,
): Promise<Resultat> {
  const invalide = erreurDateHeure(datePassage, options.heure);
  if (invalide) return { error: invalide };
  const { heure, note, ...drapeaux } = options;
  return muter((i) => `/tournees/${i}`, id, {
    method: 'PATCH',
    headers: JSON_HEADERS,
    body: JSON.stringify({
      datePassage: heure ? `${datePassage}T${heure}:00` : datePassage,
      note: note?.trim() ?? '',
      ...drapeaux,
    }),
  });
}

/** Enregistre la prévision ou la validation de la semaine côté serveur. */
export async function enregistrerSemaine(
  semaine: string,
  etape: 'prevision' | 'validation',
): Promise<Resultat> {
  if (!jourValide(semaine)) return { error: 'Semaine invalide.' };
  if (etape !== 'prevision' && etape !== 'validation') return { error: 'Étape invalide.' };
  return muter(() => `/tournees/semaine/${etape}`, null, {
    method: 'POST',
    headers: JSON_HEADERS,
    body: JSON.stringify({ semaine }),
  });
}

/** Retire une étape de mon planning. */
export async function removeEtape(id: string): Promise<Resultat> {
  return muter((i) => `/tournees/${i}`, id, { method: 'DELETE' });
}

/** Jeton personnel du flux iCal (synchronisation Outlook du planning). */
export async function getIcalInfo(): Promise<{ userId: string; token: string } | null> {
  if (await controle()) return null;
  try {
    const res = await serverFetch('/tournees/ical-token');
    if (!res.ok) return null;
    return (await res.json()) as { userId: string; token: string };
  } catch {
    return null;
  }
}
