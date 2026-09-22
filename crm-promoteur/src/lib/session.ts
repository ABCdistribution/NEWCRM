import { cookies } from 'next/headers';

// Cookie de session PARTAGÉ avec Helios (même nom, même JWT) → SSO entre les deux univers.
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
    // Secure exige HTTPS : la prod actuelle est servie en HTTP interne (pas de domaine),
    // COOKIE_SECURE=false permet donc de garder la session ; à repasser à true avec HTTPS.
    secure: process.env.COOKIE_SECURE
      ? process.env.COOKIE_SECURE === 'true'
      : process.env.NODE_ENV === 'production',
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
