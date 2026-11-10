import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { RetourSynchro } from '@/components/ad-sync-trigger';
import type { AdSyncState } from './admin-actions';

// Rendu pur du retour de la synchro AD (react-dom/server) : l'action serveur est remplacée, aucun réseau.
vi.mock('./admin-actions', () => ({ syncAd: vi.fn() }));

const STATS = {
  lus: 64,
  crees: 3,
  maj: 61,
  photos: 60,
  directeursLies: 58,
  sansRegion: [] as string[],
  sansManager: [] as string[],
  conflitsIdRepr: [] as string[],
  tronque: false,
};

const rendre = (state: AdSyncState, pending = false) =>
  renderToStaticMarkup(createElement(RetourSynchro, { state, pending }));

describe('RetourSynchro : retour visible de la synchro AD', () => {
  it('rien avant le premier lancement', () => {
    expect(rendre({ error: null, ok: false })).toBe('');
  });

  it('pendant l’attente : consigne annoncée (role=status), durée maximale indiquée', () => {
    const html = rendre({ error: null, ok: false }, true);
    expect(html).toContain('role="status"');
    expect(html).toContain('3 minutes');
  });

  it('échec : alerte annoncée (role=alert) avec la cause', () => {
    const html = rendre({ error: "L'annuaire Active Directory est injoignable depuis le serveur.", ok: false });
    expect(html).toContain('role="alert"');
    expect(html).toContain('La synchronisation a échoué');
    expect(html).toContain('injoignable depuis le serveur');
  });

  it('succès : détail du compte rendu, annoncé (role=status), sans avertissement', () => {
    const html = rendre({ error: null, ok: true, stats: STATS });
    expect(html).toContain('role="status"');
    expect(html).toContain('Synchronisation réussie');
    expect(html).toContain('64 comptes lus');
    expect(html).toContain('3 créés');
    expect(html).toContain('61 mis à jour');
    expect(html).toContain('60 photos rapatriées');
    // Les photos reprises de l'annuaire s'ajoutent au compte, sans changer le texte.
    expect(rendre({ error: null, ok: true, stats: { ...STATS, photosAnnuaire: 51 } })).toContain('111 photos rapatriées');
    expect(html).not.toContain('limite');
    expect(html).not.toContain('sans région');
  });

  it('succès avec lecture tronquée : avertit que des comptes ont pu être ignorés', () => {
    const html = rendre({ error: null, ok: true, stats: { ...STATS, tronque: true } });
    expect(html).toContain('Synchronisation réussie');
    expect(html).toContain('limite');
    expect(html).toContain('ont');
  });

  it('succès avec comptes sans région et codes en conflit : les liste', () => {
    const html = rendre({
      error: null,
      ok: true,
      stats: { ...STATS, sansRegion: ['a.dupont', 'b.martin'], conflitsIdRepr: ['c.durand (109)'] },
    });
    expect(html).toContain('2 comptes sans région reconnue');
    expect(html).toContain('a.dupont, b.martin');
    expect(html).toContain('Codes en conflit : c.durand (109)');
  });

  it('résume une longue liste de comptes sans région', () => {
    const noms = Array.from({ length: 12 }, (_, i) => `u${i}`);
    const html = rendre({ error: null, ok: true, stats: { ...STATS, sansRegion: noms } });
    expect(html).toContain('12 comptes sans région reconnue');
    expect(html).toContain('u7');
    expect(html).not.toContain('u8,');
    expect(html).toContain('et 4 autres');
  });

  it('une erreur l’emporte sur d’anciennes statistiques', () => {
    const html = rendre({ error: 'Échec', ok: false, stats: STATS });
    expect(html).toContain('role="alert"');
    expect(html).not.toContain('Synchronisation réussie');
  });
});
