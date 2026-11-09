import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const COOKIE = 'crm_session';
const PUBLIC_PATHS = ['/login'];

/**
 * Pré-filtre GROSSIER : présence du cookie de session, rien d'autre.
 * Il ne valide pas le jeton et ne décide pas du rôle : c'est le layout serveur (getMe) et
 * requireRole qui font foi.
 */
export function middleware(req: NextRequest) {
  const { pathname, search } = req.nextUrl;
  const token = req.cookies.get(COOKIE)?.value;
  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
  // Fichiers statiques (logos, images, polices…) et proxy d'avatar : exemptés
  // (le proxy d'avatar vérifie lui-même la session côté serveur).
  const isAsset = /\.(?:png|jpe?g|svg|ico|webp|gif|woff2?|css|js|map|txt|webmanifest)$/i.test(pathname) || pathname.startsWith('/avatar/');

  // Non connecté → tout sauf les pages publiques / assets renvoie vers /login (en gardant la cible).
  if (!token && !isPublic && !isAsset) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.search = '';
    url.searchParams.set('from', pathname + search);
    return NextResponse.redirect(url);
  }

  // NB : on NE renvoie JAMAIS un utilisateur « avec cookie » de /login vers /.
  // Le cookie n'est qu'une PRÉSENCE (le middleware ne peut pas le valider) ; si le jeton est
  // expiré ou si l'API est injoignable, la page protégée redirige vers /login — et un rebond
  // /login → / créerait une boucle infinie (ERR_TOO_MANY_REDIRECTS).
  return NextResponse.next();
}

export const config = {
  // On exclut l'API (proxifiée vers NestJS), les assets Next et le favicon.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
