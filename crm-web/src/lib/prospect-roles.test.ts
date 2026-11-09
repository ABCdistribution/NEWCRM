import { describe, expect, it } from 'vitest';
import type { Role } from './api';
import { MOTIFS_PERTE, estMotifPerte } from './prospect-motifs';
import { PROSPECTS_ECRITURE, peutEcrireProspects } from './prospect-roles';

const TOUS: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'COMMERCIAL', 'ADV', 'MARKETING'];

describe('PROSPECTS_ECRITURE (aligné sur POST/PATCH /prospects et POST /prospects/:id/convert de l\'API)', () => {
  it('= ADMIN, DIRECTEUR_REGIONAL, CHEF_SECTEUR', () => {
    expect([...PROSPECTS_ECRITURE].sort()).toEqual(['ADMIN', 'CHEF_SECTEUR', 'DIRECTEUR_REGIONAL']);
  });

  it('DIRECTION est en lecture seule (l\'API répond 403 à ses écritures)', () => {
    expect(PROSPECTS_ECRITURE).not.toContain('DIRECTION');
    expect(peutEcrireProspects('DIRECTION')).toBe(false);
  });

  it.each(TOUS)('%s : peutEcrireProspects suit la liste', (role) => {
    expect(peutEcrireProspects(role)).toBe(PROSPECTS_ECRITURE.includes(role));
  });

  it('les rôles terrain et MARKETING n\'écrivent pas (espace Direction réservé à l\'encadrement)', () => {
    for (const r of ['COMMERCIAL', 'ADV', 'MARKETING'] as const) expect(peutEcrireProspects(r)).toBe(false);
  });
});

describe('motifs de perte', () => {
  it('cinq motifs, valeurs de l\'énumération API', () => {
    expect(MOTIFS_PERTE.map(([code]) => code)).toEqual(['PRIX', 'CONCURRENCE', 'PAS_DE_BESOIN', 'SANS_REPONSE', 'AUTRE']);
  });

  it('estMotifPerte accepte un motif connu et refuse le reste', () => {
    expect(estMotifPerte('PRIX')).toBe(true);
    expect(estMotifPerte('prix')).toBe(false);
    expect(estMotifPerte('')).toBe(false);
    expect(estMotifPerte(undefined)).toBe(false);
    expect(estMotifPerte({})).toBe(false);
  });
});
