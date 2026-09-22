import { cookies } from 'next/headers';

// Cookie de session PARTAGÉ entre Helios (pilotage) et Selios (terrain).
// Les cookies ne sont pas isolés par port : un nom commun suffit à partager le JWT
// entre :3001 et :3002 sur le même hôte → SSO, une seule connexion pour les deux univers.
const COOKIE = 'crm_session';
const MAX_AGE = 60 * 60 * 8; // 8h — aligné sur JWT_EXPIRES_IN de l'API

/** Base de l'API NestJS (appels serveur→serveur, pas de CORS). */
export function apiBase(): string {
  return process.env.API_URL ?? 'http://localhost:4000';
}

/** Écrit le JWT de session dans un cookie httpOnly. */
export async function setSession(token: string): Promise<void> {
  const store = await cookies();
  store.set(COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: MAX_AGE,
  });
}

/** Renvoie le JWT courant, ou null si pas de session. */
export async function getToken(): Promise<string | null> {
  const store = await cookies();
  return store.get(COOKIE)?.value ?? null;
}

/** Supprime le cookie de session. */
export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(COOKIE);
}
