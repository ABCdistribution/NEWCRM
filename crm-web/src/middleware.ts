import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const COOKIE = 'crm_session';
const PUBLIC_PATHS = ['/login'];
// Même valeur que ENTETE_CHEMIN dans src/lib/roles.ts (non importé : le middleware reste autonome, sans
// dépendre de modules serveur). Un test vérifie que les deux restent identiques.
const ENTETE_CHEMIN = 'x-crm-chemin';

/** Chemin demandé avec sa requête, sans le paramètre interne `_rsc` de Next (navigations côté client). */
function cheminDemande(pathname: string, search: string): string {
  if (!search.includes('_rsc')) return pathname + search;
  const params = new URLSearchParams(search);
  params.delete('_rsc');
  const requete = params.toString();
  return requete ? `${pathname}?${requete}` : pathname;
}

/**
 * Pré-filtre GROSSIER : présence du cookie de session, rien d'autre.
 * Il ne valide pas le jeton et ne décide pas du rôle : c'est le layout serveur (lireSession) et
 * requireRole qui font foi.
 *
 * Il transmet aussi aux composants serveur le chemin demandé (en-tête ENTETE_CHEMIN), pour qu'une session
 * expirée (cookie présent, jeton refusé par l'API) renvoie vers `/login?from=<page demandée>` comme une session
 * absente. L'en-tête est RÉÉCRIT à chaque requête : une valeur envoyée par le client est écrasée.
 */
export function middleware(req: NextRequest) {
  const { pathname, search } = req.nextUrl;
  const token = req.cookies.get(COOKIE)?.value;
  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
  // Fichiers statiques (logos, images, polices…) et proxy d'avatar : exemptés
  // (le proxy d'avatar vérifie lui-même la session côté serveur).
  const isAsset = /\.(?:png|jpe?g|svg|ico|webp|gif|woff2?|css|js|map|txt|webmanifest)$/i.test(pathname) || pathname.startsWith('/avatar/');
  const chemin = cheminDemande(pathname, search);

  // Non connecté → tout sauf les pages publiques / assets renvoie vers /login (en gardant la cible).
  if (!token && !isPublic && !isAsset) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.search = '';
    url.searchParams.set('from', chemin);
    return NextResponse.redirect(url);
  }

  // NB : on NE renvoie JAMAIS un utilisateur « avec cookie » de /login vers /.
  // Le cookie n'est qu'une PRÉSENCE (le middleware ne peut pas le valider) ; si le jeton est
  // expiré ou si l'API est injoignable, la page protégée redirige vers /login — et un rebond
  // /login → / créerait une boucle infinie (ERR_TOO_MANY_REDIRECTS).
  const entetes = new Headers(req.headers);
  entetes.set(ENTETE_CHEMIN, chemin);
  return NextResponse.next({ request: { headers: entetes } });
}

export const config = {
  // On exclut l'API (proxifiée vers NestJS), les assets Next et le favicon.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
