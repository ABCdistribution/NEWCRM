'use server';

import { redirect } from 'next/navigation';
import { apiBase, setSession, clearSession } from './session';

export type LoginState = { error: string | null };

/** N'autorise qu'une redirection interne (évite l'open-redirect via ?from=). */
function safeInternalPath(path: string | null | undefined): string {
  if (path && path.startsWith('/') && !path.startsWith('//')) return path;
  return '/';
}

/**
 * Server Action de connexion.
 * Appelle l'API NestJS (LDAP) côté serveur, pose le cookie de session, puis redirige.
 */
export async function login(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const username = String(formData.get('username') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const from = safeInternalPath(String(formData.get('from') ?? '/'));

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

  if (res.status === 401) return { error: 'Identifiant ou mot de passe incorrect.' };
  if (res.status === 503) return { error: 'Annuaire (LDAP) momentanément injoignable. Réessaie plus tard.' };
  if (!res.ok) return { error: `Erreur inattendue du serveur (${res.status}).` };

  const data = (await res.json()) as { accessToken?: string };
  if (!data.accessToken) return { error: 'Réponse invalide du serveur (jeton manquant).' };

  await setSession(data.accessToken);
  redirect(from);
}

/** Server Action de déconnexion. */
export async function logout(): Promise<void> {
  await clearSession();
  redirect('/login');
}
