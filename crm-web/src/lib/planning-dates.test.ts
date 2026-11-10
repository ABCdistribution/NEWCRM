import { afterEach, describe, expect, it, vi } from 'vitest';
import { aujourdhuiParis, dateSemaine, iso, mondayOf } from './planning-dates';
import { lundiDemande } from './equipe-utils';

// « Aujourd'hui » se calcule à Paris (fuseau de l'API), quel que soit le fuseau du processus Next (souvent UTC en
// conteneur) : on fige l'horloge à des instants UTC choisis autour de minuit à Paris.
afterEach(() => {
  vi.useRealTimers();
});

const A = (instantUtc: string) => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(instantUtc));
};

describe('aujourdhuiParis', () => {
  it('lundi 00h30 à Paris (dimanche 23h30 UTC, hiver) : déjà lundi, semaine courante = ce lundi', () => {
    A('2026-11-08T23:30:00Z'); // dimanche 8 nov. 23h30 UTC = lundi 9 nov. 00h30 à Paris (UTC+1)
    expect(iso(aujourdhuiParis())).toBe('2026-11-09');
    expect(iso(mondayOf(aujourdhuiParis()))).toBe('2026-11-09');
  });

  it('lundi 01h30 à Paris en été (dimanche 23h30 UTC) : déjà lundi (UTC+2)', () => {
    A('2026-07-05T23:30:00Z'); // dimanche 5 juil. 23h30 UTC = lundi 6 juil. 01h30 à Paris
    expect(iso(aujourdhuiParis())).toBe('2026-07-06');
    expect(iso(mondayOf(aujourdhuiParis()))).toBe('2026-07-06');
  });

  it('dimanche 22h à Paris : toujours la semaine qui se termine', () => {
    A('2026-11-08T21:00:00Z'); // dimanche 8 nov. 22h00 à Paris
    expect(iso(aujourdhuiParis())).toBe('2026-11-08');
    expect(iso(mondayOf(aujourdhuiParis()))).toBe('2026-11-02');
  });

  it('passage au mois suivant à Paris avant minuit UTC', () => {
    A('2026-10-31T23:30:00Z'); // samedi 31 oct. 23h30 UTC = dimanche 1er nov. 00h30 à Paris (UTC+1 depuis le 25 oct.)
    const d = aujourdhuiParis();
    expect([d.getFullYear(), d.getMonth() + 1, d.getDate()]).toEqual([2026, 11, 1]);
  });
});

describe('dateSemaine / lundiDemande', () => {
  it('sans paramètre : jour courant à Paris', () => {
    A('2026-11-08T23:30:00Z');
    expect(iso(dateSemaine())).toBe('2026-11-09');
    expect(iso(lundiDemande(undefined))).toBe('2026-11-09');
  });

  it('paramètre invalide : retombe sur la semaine courante', () => {
    A('2026-11-08T23:30:00Z');
    expect(iso(dateSemaine('pas-une-date'))).toBe('2026-11-09');
    expect(iso(lundiDemande('2026-13-45'))).toBe('2026-11-09');
  });

  it('paramètre valide : respecté tel quel', () => {
    A('2026-11-08T23:30:00Z');
    expect(iso(dateSemaine('2026-03-04'))).toBe('2026-03-04');
    expect(iso(lundiDemande('2026-03-04'))).toBe('2026-03-02');
  });
});
