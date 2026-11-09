import { cookies } from 'next/headers';

// Cookie de session `crm_session` (JWT), identique à celui des anciens fronts : pendant la
// migration, une connexion sur :3000/:3001 reste valable sur :3002 (même hôte, ports non isolés).
const COOKIE = 'crm_session';
const MAX_AGE = 60 * 60 * 8; // 8h — aligné sur JWT_EXPIRES_IN de l'API

/** Base de l'API NestJS (appels serveur→serveur, pas de CORS). */
export function apiBase(): string {
  return process.env.API_URL ?? 'http://localhost:4000';
}

/**
 * Attribut `secure` du cookie de session.
 *
 * Secure exige HTTPS : la prod actuelle est servie en HTTP interne (pas de domaine), COOKIE_SECURE=false permet
 * donc de garder la session ; à repasser à true dès que HTTPS est en place (backlog 1.11).
 *
 * Seules les valeurs « true » et « false » (casse et espaces ignorés) sont reconnues. Toute autre valeur
 * (« 0 », « faux », faute de frappe…) est ignorée avec un avertissement et le défaut s'applique : secure en
 * production. Un cookie non sécurisé est ainsi toujours un choix explicite, jamais un accident de saisie.
 */
export function cookieSecure(): boolean {
  const production = process.env.NODE_ENV === 'production';
  const brut = process.env.COOKIE_SECURE?.trim();
  const valeur = brut?.toLowerCase();
  if (valeur === 'true') return true;
  if (valeur === 'false') {
    if (production) {
      console.warn(
        'Sécurité : COOKIE_SECURE=false en production : le cookie de session et le mot de passe circulent en clair ' +
          'sur HTTP. À repasser à true dès que HTTPS est en place.',
      );
    }
    return false;
  }
  if (brut) {
    console.warn(`Sécurité : COOKIE_SECURE « ${brut} » non reconnu (attendu : true ou false) : valeur ignorée.`);
  }
  return production;
}

/** Écrit le JWT de session dans un cookie httpOnly. */
export async function setSession(token: string): Promise<void> {
  const store = await cookies();
  store.set(COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: cookieSecure(),
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
