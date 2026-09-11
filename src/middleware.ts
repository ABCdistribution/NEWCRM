import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const COOKIE = 'helios_session';
const PUBLIC_PATHS = ['/login'];

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const token = req.cookies.get(COOKIE)?.value;
  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));

  // Non connecté → tout sauf les pages publiques renvoie vers /login (en gardant la cible).
  if (!token && !isPublic) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('from', pathname);
    return NextResponse.redirect(url);
  }

  // NB : on NE renvoie PAS un utilisateur « avec cookie » de /login vers /.
  // Le cookie n'est qu'une PRÉSENCE (le middleware ne peut pas le valider) ; si le
  // jeton est expiré ou si l'API est injoignable, la page protégée redirige vers
  // /login — et un bounce /login→/ créerait une boucle infinie (ERR_TOO_MANY_REDIRECTS).
  return NextResponse.next();
}

export const config = {
  // On exclut l'API (proxifiée vers NestJS), les assets Next et le favicon.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
