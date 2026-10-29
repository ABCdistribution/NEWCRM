'use server';

import { redirect } from 'next/navigation';
import { headers } from 'next/headers';
import { apiBase, setSession, clearSession } from './session';

/** `externe` : adresse d'un autre univers (autre port = autre origine), que le formulaire ouvre lui-même. */
export type LoginState = { error: string | null; externe?: string };

/** Rôles de l'encadrement → univers ABC Pilot (pilotage). Les autres (COMMERCIAL, ADV) → ABC Sales. */
const HELIOS_ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** URL de ABC Sales sur le même serveur (hôte déduit de la requête, port configurable). */
async function seliosUrl(): Promise<string> {
  const host = (await headers()).get('host')?.split(':')[0] ?? 'localhost';
  return `http://${host}:${process.env.SELIOS_PORT ?? '3002'}`;
}

/** N'autorise qu'une redirection interne (évite l'open-redirect via ?from=). */
function safeInternalPath(path: string | null | undefined): string {
  if (path && path.startsWith('/') && !path.startsWith('//')) return path;
  return '/pilotage';
}

/**
 * Server Action de connexion.
 * Appelle l'API NestJS (LDAP) côté serveur, pose le cookie de session, puis redirige.
 */
export async function login(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const username = String(formData.get('username') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const from = safeInternalPath(String(formData.get('from') ?? '/pilotage'));

  if (!username || !password) {
    return { error: 'Identifiant et mot de passe requis.' };
  }

  let res: Response;
  try {
    res = await fetch(`${apiBase()}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
      cache: 'no-store',
    });
  } catch {
    return { error: "Impossible de joindre le serveur. Vérifie que l'API est démarrée." };
  }

  if (res.status === 401) {
    // Trace serveur (jamais le mot de passe) : distingue « identifiants invalides » de « compte désactivé ».
    const detail = await res.clone().json().catch(() => null);
    console.warn(`[login] 401 pour « ${username} » (${username.length} car.) — API : ${JSON.stringify(detail?.message ?? detail)}`);
    return { error: 'Identifiant ou mot de passe incorrect.' };
  }
  if (res.status === 503) return { error: 'Annuaire (LDAP) momentanément injoignable. Réessaie plus tard.' };
  if (!res.ok) return { error: `Erreur inattendue du serveur (${res.status}).` };

  const data = (await res.json()) as { accessToken?: string };
  if (!data.accessToken) return { error: 'Réponse invalide du serveur (jeton manquant).' };

  await setSession(data.accessToken);

  // Oriente selon le rôle : encadrement → ABC Pilot, COMMERCIAL/ADV → ABC Sales.
  let role: string | null = null;
  try {
    const meRes = await fetch(`${apiBase()}/auth/me`, {
      headers: { Authorization: `Bearer ${data.accessToken}` },
      cache: 'no-store',
    });
    if (meRes.ok) role = ((await meRes.json()) as { role?: string }).role ?? null;
  } catch {
    /* si /auth/me échoue, on tombe sur ABC Pilot par défaut */
  }

  // Une Server Action ne peut pas rediriger vers une autre origine (« unexpected response ») : on renvoie l'adresse.
  if (role && !HELIOS_ROLES.includes(role)) {
    return { error: null, externe: await seliosUrl() };
  }
  redirect(from);
}

/** Server Action de déconnexion. */
export async function logout(): Promise<void> {
  await clearSession();
  redirect('/login');
}
