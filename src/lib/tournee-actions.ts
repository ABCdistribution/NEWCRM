'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, listClients, listProspects } from './api';

const PAGE = '/pilotage/ma-tournee';

/** Cible proposée dans la recherche d'ajout : magasin existant ou prospect. */
export type CibleTournee = {
  type: 'CLIENT' | 'PROSPECT';
  id: string;
  enseigne: string;
  ville: string | null;
  niveauClass: string | null;
};

/** Recherche mêlée magasins + prospects (pour la combobox d'ajout d'étape). */
export async function searchCibles(q: string): Promise<CibleTournee[]> {
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
};

/** Ajoute une étape (prospect, magasin ou ADM) à MON planning. */
export async function addEtape(
  cible: { type: 'CLIENT' | 'PROSPECT' | 'ADM'; id?: string },
  datePassage: string,
  options: OptionsEtape = {},
): Promise<{ error: string | null }> {
  const { heure, note, ...drapeaux } = options;
  let res: Response;
  try {
    res = await serverFetch('/tournees', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        datePassage: heure ? `${datePassage}T${heure}:00` : datePassage,
        ...(note?.trim() ? { note: note.trim() } : {}),
        ...drapeaux,
        ...(cible.type === 'ADM'
          ? { adm: true }
          : cible.type === 'CLIENT'
            ? { clientId: cible.id }
            : { prospectId: cible.id }),
      }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  revalidatePath(PAGE);
  return { error: null };
}

/** Coche / décoche une étape (visite faite). */
export async function toggleEtapeFaite(id: string, fait: boolean): Promise<{ error: string | null }> {
  try {
    const res = await serverFetch(`/tournees/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fait }),
    });
    if (!res.ok) return { error: `Erreur serveur (${res.status}).` };
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  revalidatePath(PAGE);
  return { error: null };
}

/** Déplace une étape vers une autre date (drag & drop entre jours). */
export async function moveEtape(id: string, datePassage: string): Promise<{ error: string | null }> {
  try {
    const res = await serverFetch(`/tournees/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ datePassage }),
    });
    if (!res.ok) return { error: `Erreur serveur (${res.status}).` };
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  revalidatePath(PAGE);
  return { error: null };
}

/** Retire une étape de mon planning. */
export async function removeEtape(id: string): Promise<void> {
  await serverFetch(`/tournees/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath(PAGE);
}

/** Jeton personnel du flux iCal (synchronisation Outlook du planning). */
export async function getIcalInfo(): Promise<{ userId: string; token: string } | null> {
  try {
    const res = await serverFetch('/tournees/ical-token');
    if (!res.ok) return null;
    return (await res.json()) as { userId: string; token: string };
  } catch {
    return null;
  }
}
