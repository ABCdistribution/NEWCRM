import { NextRequest } from 'next/server';
import { describe, expect, it } from 'vitest';
import { middleware } from './middleware';
import { ENTETE_CHEMIN } from '@/lib/roles';

// Aucun mock : le middleware est une fonction pure de la requête (cookie, adresse, en-têtes).

/** Next transmet les en-têtes de requête réécrits par le middleware dans ces en-têtes de réponse internes. */
const entetePourLaPage = (res: Response, nom: string): string | null => res.headers.get(`x-middleware-request-${nom}`);

function requete(adresse: string, init: { cookie?: string; entetes?: Record<string, string> } = {}): NextRequest {
  const entetes = new Headers(init.entetes);
  if (init.cookie) entetes.set('cookie', init.cookie);
  return new NextRequest(`http://localhost:3002${adresse}`, { headers: entetes });
}

describe('middleware : sans cookie de session', () => {
  it('redirige vers /login en gardant la cible (?from=)', () => {
    const res = middleware(requete('/rapports?semaine=2026-01-05'));

    expect(res.status).toBe(307);
    const cible = new URL(res.headers.get('location')!);
    expect(cible.pathname).toBe('/login');
    expect(cible.searchParams.get('from')).toBe('/rapports?semaine=2026-01-05');
  });

  it('la cible ne retient pas le paramètre interne _rsc des navigations côté client', () => {
    const res = middleware(requete('/rapports?semaine=2026-01-05&_rsc=abc12'));

    expect(new URL(res.headers.get('location')!).searchParams.get('from')).toBe('/rapports?semaine=2026-01-05');
  });

  it('laisse passer /login et les fichiers statiques', () => {
    for (const adresse of ['/login', '/logo.png', '/avatar/123e4567-e89b-42d3-a456-426614174000']) {
      expect(middleware(requete(adresse)).headers.get('location'), adresse).toBeNull();
    }
  });
});

describe('middleware : avec cookie de session', () => {
  const COOKIE = 'crm_session=jeton-de-test';

  it('ne redirige pas (le cookie n\'est qu\'une présence : jamais de rebond /login -> /)', () => {
    expect(middleware(requete('/login', { cookie: COOKIE })).headers.get('location')).toBeNull();
    expect(middleware(requete('/clients', { cookie: COOKIE })).headers.get('location')).toBeNull();
  });

  it('transmet le chemin demandé (requête comprise) aux composants serveur', () => {
    const res = middleware(requete('/rapports?semaine=2026-01-05', { cookie: COOKIE }));

    expect(entetePourLaPage(res, ENTETE_CHEMIN)).toBe('/rapports?semaine=2026-01-05');
  });

  it('sans requête : le chemin seul', () => {
    expect(entetePourLaPage(middleware(requete('/clients', { cookie: COOKIE })), ENTETE_CHEMIN)).toBe('/clients');
  });

  it('retire _rsc du chemin transmis, garde les autres paramètres', () => {
    const res = middleware(requete('/clients?search=leclerc&_rsc=x1', { cookie: COOKIE }));

    expect(entetePourLaPage(res, ENTETE_CHEMIN)).toBe('/clients?search=leclerc');
  });

  it('écrase une valeur envoyée par le client (l\'en-tête ne peut pas être forgé)', () => {
    const res = middleware(requete('/clients', { cookie: COOKIE, entetes: { [ENTETE_CHEMIN]: '//evil.example' } }));

    expect(entetePourLaPage(res, ENTETE_CHEMIN)).toBe('/clients');
  });
});

describe('ENTETE_CHEMIN', () => {
  it('le nom d\'en-tête du middleware est celui que lit roles.ts', () => {
    // Le middleware ne l'importe pas (il reste autonome) : si les deux divergent, ?from= ne serait plus transmis.
    expect(ENTETE_CHEMIN).toBe('x-crm-chemin');
    const res = middleware(requete('/clients', { cookie: 'crm_session=x' }));
    expect(entetePourLaPage(res, ENTETE_CHEMIN)).not.toBeNull();
  });
});
