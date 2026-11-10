import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// `next/headers` (cookies) est remplacé : aucune requête, aucune session. On observe seulement les options du cookie.
const mocks = vi.hoisted(() => ({ set: vi.fn() }));
vi.mock('next/headers', () => ({ cookies: async () => ({ set: mocks.set, get: vi.fn(), delete: vi.fn() }) }));

import { cookieSecure, setSession } from './session';

let avertissement: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  mocks.set.mockReset();
  avertissement = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
});

afterEach(() => {
  vi.unstubAllEnvs();
  avertissement.mockRestore();
});

/** Pose l'environnement : `undefined` retire la variable. */
function env(nodeEnv: string, cookieSecureEnv: string | undefined): void {
  vi.stubEnv('NODE_ENV', nodeEnv);
  if (cookieSecureEnv === undefined) vi.stubEnv('COOKIE_SECURE', '');
  else vi.stubEnv('COOKIE_SECURE', cookieSecureEnv);
}

describe('cookieSecure', () => {
  it('sans COOKIE_SECURE : secure en production, non secure en développement', () => {
    env('production', undefined);
    expect(cookieSecure()).toBe(true);
    env('development', undefined);
    expect(cookieSecure()).toBe(false);
    expect(avertissement).not.toHaveBeenCalled();
  });

  it.each(['true', 'TRUE', ' True '])('COOKIE_SECURE=%j : secure, même en développement', (valeur) => {
    env('development', valeur);
    expect(cookieSecure()).toBe(true);
  });

  it.each(['false', 'False', ' FALSE '])('COOKIE_SECURE=%j : non secure, choix explicite', (valeur) => {
    env('production', valeur);
    expect(cookieSecure()).toBe(false);
  });

  it('COOKIE_SECURE=false en production : avertissement (cookie et mot de passe en clair)', () => {
    env('production', 'false');
    cookieSecure();
    expect(avertissement).toHaveBeenCalledTimes(1);
    expect(String(avertissement.mock.calls[0][0])).toContain('COOKIE_SECURE=false');
  });

  it('COOKIE_SECURE=false en développement : pas d\'avertissement', () => {
    env('development', 'false');
    cookieSecure();
    expect(avertissement).not.toHaveBeenCalled();
  });

  it.each(['0', 'faux', 'no', 'tru'])('valeur non reconnue %j : ignorée avec un avertissement, défaut selon NODE_ENV', (valeur) => {
    env('production', valeur);
    expect(cookieSecure()).toBe(true); // jamais un cookie non sécurisé par accident de saisie
    expect(avertissement).toHaveBeenCalledTimes(1);

    env('development', valeur);
    expect(cookieSecure()).toBe(false);
  });
});

describe('setSession', () => {
  it('pose un cookie httpOnly, sameSite lax, valable 8 h, avec l\'attribut secure calculé', async () => {
    env('production', undefined);
    await setSession('jeton-de-test');

    expect(mocks.set).toHaveBeenCalledTimes(1);
    const [nom, valeur, options] = mocks.set.mock.calls[0];
    expect(nom).toBe('crm_session');
    expect(valeur).toBe('jeton-de-test');
    expect(options).toMatchObject({ httpOnly: true, sameSite: 'lax', secure: true, path: '/', maxAge: 60 * 60 * 8 });
  });
});
