import { describe, expect, it, vi } from 'vitest';
import { ORIGINES, origineDe, parseOrigine } from './origine-commande';

// Le fichier contient aussi des composants (JSX) : leur lien Next est neutralisé, seules les fonctions pures sont testées.
vi.mock('next/link', () => ({ default: () => null }));

/** Valeur volontairement hors du contrat de type (réponse d'API inattendue, paramètre d'URL répété). */
const horsContrat = <T>(valeur: unknown): T => valeur as T;

describe('origineDe (règle provisoire : viaMobile)', () => {
  it('viaMobile = true : saisie mobile, « appli »', () => {
    expect(origineDe({ viaMobile: true })).toBe('appli');
  });

  it('viaMobile = false : « edi »', () => {
    expect(origineDe({ viaMobile: false })).toBe('edi');
  });

  it.each([
    ['champ absent (API pas à jour)', {}],
    ['champ undefined', { viaMobile: undefined }],
  ])('%s : origine inconnue (undefined)', (_libelle, commande) => {
    expect(origineDe(commande)).toBeUndefined();
  });

  it.each([
    ['null', null],
    ['chaîne « true »', 'true'],
    ['chaîne « false »', 'false'],
    ['nombre 1', 1],
    ['nombre 0', 0],
    ['objet', {}],
  ])('valeur non booléenne (%s) : jamais convertie, origine inconnue', (_libelle, valeur) => {
    expect(origineDe(horsContrat<{ viaMobile?: boolean }>({ viaMobile: valeur }))).toBeUndefined();
  });

  it('ignore les autres champs de la commande', () => {
    expect(origineDe({ viaMobile: true, ...{ numero: 'CMD-1', total: 12 } })).toBe('appli');
  });
});

describe('parseOrigine (paramètre d\'URL ?origine=)', () => {
  it.each([
    ['edi', 'edi'],
    ['appli', 'appli'],
  ] as const)('« %s » : accepté', (valeur, attendu) => {
    expect(parseOrigine(valeur)).toBe(attendu);
  });

  it.each([
    ['absent', undefined],
    ['chaîne vide', ''],
    ['majuscules', 'EDI'],
    ['casse mixte', 'Appli'],
    ['espace final', 'edi '],
    ['deux valeurs', 'edi,appli'],
    ['valeur inconnue', 'toutes'],
    ['tentative d\'injection', 'edi&role=ADMIN'],
  ])('%s : ignoré (undefined)', (_libelle, valeur) => {
    expect(parseOrigine(valeur)).toBeUndefined();
  });

  it('paramètre répété (?origine=edi&origine=appli, tableau côté Next) : ignoré, sans lever', () => {
    expect(parseOrigine(horsContrat<string>(['edi', 'appli']))).toBeUndefined();
    expect(parseOrigine(horsContrat<string>(['edi']))).toBeUndefined();
  });
});

describe('ORIGINES', () => {
  it('liste exactement « appli » et « edi », chacune reconnue par parseOrigine', () => {
    expect(ORIGINES.map((o) => o.value).sort()).toEqual(['appli', 'edi']);
    for (const { value } of ORIGINES) expect(parseOrigine(value)).toBe(value);
  });

  it('chaque origine a un libellé affichable non vide', () => {
    for (const { label } of ORIGINES) expect(label.trim()).not.toBe('');
  });
});
