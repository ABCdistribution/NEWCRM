'use server';

import { redirect } from 'next/navigation';
import { apiBase, setSession, clearSession } from './session';
import { cheminInterneSur } from './chemin';

export type LoginState = { error: string | null };

/**
 * Server Action de connexion : appelle l'API NestJS (AD puis JWT) côté serveur,
 * pose le cookie de session httpOnly, puis redirige vers `from` (interne) ou `/`.
 *
 * Le chemin `from` est assaini par `cheminInterneSur` (src/lib/chemin.ts).
 */
export async function login(_prev: LoginState, formData: FormData): Promise<LoginState> {
  const username = String(formData.get('username') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const from = cheminInterneSur(String(formData.get('from') ?? '/'));

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
      // Délai d'attente : l'API interroge l'AD, ce qui peut prendre quelques secondes ; au-delà, on ne bloque pas le formulaire.
      signal: AbortSignal.timeout(30_000),
    });
  } catch {
    return { error: 'Impossible de joindre le serveur. Réessaie dans un instant.' };
  }

  // Même message pour « utilisateur inconnu », « mot de passe faux » et « compte désactivé » :
  // on ne révèle pas si le compte existe. Aucune trace de l'identifiant ni du mot de passe.
  if (res.status === 401) return { error: 'Identifiant ou mot de passe incorrect.' };
  if (res.status === 429) return { error: 'Trop de tentatives. Réessaie dans quelques minutes.' };
  if (res.status === 503) return { error: 'Annuaire momentanément injoignable. Réessaie plus tard.' };
  if (!res.ok) return { error: `Erreur inattendue du serveur (${res.status}).` };

  let accessToken: string | undefined;
  try {
    accessToken = ((await res.json()) as { accessToken?: string }).accessToken;
  } catch {
    accessToken = undefined;
  }
  if (!accessToken) return { error: 'Réponse invalide du serveur. Réessaie plus tard.' };

  await setSession(accessToken);
  // Même origine uniquement : le chemin a été assaini plus haut.
  redirect(from);
}

/** Server Action de déconnexion : vide le cookie puis renvoie vers /login. */
export async function logout(): Promise<void> {
  await clearSession();
  redirect('/login');
}
