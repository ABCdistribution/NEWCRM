import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

// Cookie de session PARTAGÉ avec Helios (même nom, même JWT) → SSO.
const COOKIE = 'crm_session';
// Point de connexion UNIQUE : la page de login neutre servie par Helios (même serveur).
const HELIOS_PORT = process.env.HELIOS_PORT ?? '3001';

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const token = req.cookies.get(COOKIE)?.value;
  // Fichiers statiques (logos, images, polices…) servis depuis /public : accessibles sans session.
  const isAsset = /\.[a-z0-9]+$/i.test(pathname);

  // Selios n'a plus de page de login : tout non-connecté est renvoyé vers le login unique
  // d'Helios. Après connexion, la Server Action d'Helios réoriente selon le rôle (les rôles
  // terrain reviennent ici) — et le cookie partagé fait qu'aucune reconnexion n'est demandée.
  if (!token && !isAsset) {
    const host = req.headers.get('host')?.split(':')[0] ?? 'localhost';
    return NextResponse.redirect(new URL(`http://${host}:${HELIOS_PORT}/login`));
  }

  return NextResponse.next();
}

export const config = {
  // On exclut l'API (proxifiée vers NestJS), les assets Next et le favicon.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
