'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { messageErreurApi } from './erreurs-api';
import { exigerRole, messageRefus } from './roles';
import {
  ROLES_FREQUENCES_PEM,
  ROLES_SUIVI_PEM,
  estUuid,
  lireFrequences,
  lireProposition,
  type ReponseSuiviPem,
} from './pem';

const INJOIGNABLE = "Impossible de joindre l'API.";
const champ = (fd: FormData, nom: string): string => String(fd.get(nom) ?? '');

/**
 * Active ou désactive le suivi PEM d'un magasin (`PATCH /clients/:id/suivi-pem`) : ADMIN, DIRECTION et DIRECTEUR_REGIONAL
 * (le directeur régional est limité à sa région par l'API : son refus est relayé tel quel). Désactiver annule la
 * proposition ouverte ; activer en programme une aussitôt, renvoyée si elle existe.
 */
export async function changerSuiviPem(formData: FormData): Promise<ReponseSuiviPem> {
  try {
    await exigerRole(ROLES_SUIVI_PEM);
  } catch (e) {
    return { error: messageRefus(e, 'Accès refusé : action réservée à la direction et aux directeurs régionaux.') };
  }
  const clientId = champ(formData, 'clientId');
  const valeur = champ(formData, 'suiviPem');
  if (!estUuid(clientId)) return { error: 'Client invalide.' };
  if (valeur !== 'true' && valeur !== 'false') return { error: 'Valeur invalide.' };
  const suiviPem = valeur === 'true';

  let res: Response;
  try {
    res = await serverFetch(`/clients/${encodeURIComponent(clientId)}/suivi-pem`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ suiviPem }),
    });
  } catch {
    return { error: INJOIGNABLE };
  }
  if (!res.ok) return { error: await messageErreurApi(res, 'suivi PEM') };

  let proposition = null;
  try {
    const corps = (await res.json()) as { proposition?: unknown };
    proposition = suiviPem ? lireProposition(corps.proposition) : null;
  } catch {
    // Le changement est enregistré (statut 2xx) : seule la proposition affichée est perdue, la fiche se recharge.
    proposition = null;
  }
  revalidatePath(`/clients/${clientId}`);
  revalidatePath('/clients');
  return { error: null, suiviPem, proposition };
}

/** Enregistre la fréquence (en semaines) des 7 classes (`PUT /pem/frequences`) : ADMIN et DIRECTION. */
export async function enregistrerFrequencesPem(formData: FormData): Promise<string | null> {
  try {
    await exigerRole(ROLES_FREQUENCES_PEM);
  } catch (e) {
    return messageRefus(e, 'Accès refusé : action réservée aux administrateurs.');
  }
  const { classes, erreur } = lireFrequences((nom) => champ(formData, nom));
  if (!classes) return erreur;

  let res: Response;
  try {
    res = await serverFetch('/pem/frequences', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ classes }),
    });
  } catch {
    return INJOIGNABLE;
  }
  if (!res.ok) return messageErreurApi(res, 'admin visites PEM : fréquences');
  revalidatePath('/admin');
  return null;
}
