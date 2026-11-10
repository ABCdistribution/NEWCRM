import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import {
  assainirPassesInactifs,
  dateHeure,
  envoiAdv,
  jourLong,
  moisCourant,
  moisValide,
  peutVoirPassesInactifs,
  versCsv,
  type ClientPasseInactif,
} from './clients-inactifs';

// Le rendu n'exécute aucune Server Action : elle est remplacée par une coquille vide.
vi.mock('./clients-inactifs-actions', () => ({ chargerPassesInactifs: async () => ({ indisponible: true }) }));
const { ClientsInactifs } = await import('@/components/clients-inactifs');

const ID = '3f2c1b9e-7d4a-4c1e-9a55-0b1c2d3e4f50';
const nbsp = (s: string) => s.replace(/[  ]/g, ' ');

const LIGNE = (plus: Partial<ClientPasseInactif> = {}): ClientPasseInactif => ({
  id: ID,
  enseigne: 'U EXPRESS 94 VINCENNES',
  codeAs400: '004701',
  ville: 'VINCENNES',
  date: '2026-11-09T07:17:00Z',
  modifiePar: 'Delphine SUAU',
  dr: 'Delphine SUAU',
  retireAs400: false,
  envoyeAdvLe: '2026-11-10T08:00:00Z',
  ...plus,
});

describe('droits et mois', () => {
  it('bouton réservé à l’encadrement et à l’ADV', () => {
    for (const role of ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'ADV'] as const) expect(peutVoirPassesInactifs(role)).toBe(true);
    for (const role of ['COMMERCIAL', 'MARKETING'] as const) expect(peutVoirPassesInactifs(role)).toBe(false);
  });

  it('mois « AAAA-MM » seulement', () => {
    expect(moisValide('2026-11')).toBe(true);
    for (const m of ['2026-13', '2026-00', '26-11', '2026-1', '2026-11-01', '', null, 42, '2026-11; DROP']) expect(moisValide(m)).toBe(false);
  });

  it('mois courant à Paris', () => {
    expect(moisCourant(new Date('2026-11-10T12:00:00Z'))).toBe('2026-11');
    expect(moisCourant(new Date('2026-11-30T23:30:00Z'))).toBe('2026-12'); // déjà le 1er décembre à Paris
  });
});

describe('lecture défensive de la réponse de l’API', () => {
  it('lignes valides conservées, historique non enregistré signalé', () => {
    const r = assainirPassesInactifs({ disponible: true, depuis: '2026-10-01', lignes: [{ ...LIGNE() }] });
    expect(r.disponible).toBe(true);
    expect(r.depuis).toBe('2026-10-01');
    expect(r.lignes).toHaveLength(1);
    expect(assainirPassesInactifs({ disponible: false, depuis: null, lignes: [] }).disponible).toBe(false);
  });

  it('écarte les lignes sans UUID, sans enseigne ou sans date valide', () => {
    const r = assainirPassesInactifs({
      lignes: [{ ...LIGNE(), id: '../admin' }, { ...LIGNE(), enseigne: '' }, { ...LIGNE(), date: 'hier' }, LIGNE()],
    });
    expect(r.lignes).toHaveLength(1);
  });

  it('toute autre forme donne « aucune ligne »', () => {
    for (const brut of [null, undefined, 'x', 42, {}, { lignes: 'x' }, { lignes: [null, 3] }]) {
      expect(assainirPassesInactifs(brut).lignes).toEqual([]);
    }
  });

  it('borne le nombre de lignes à 2 000', () => {
    const lignes = Array.from({ length: 2500 }, () => LIGNE());
    expect(assainirPassesInactifs({ lignes }).lignes).toHaveLength(2000);
  });
});

describe('libellés', () => {
  it('colonne « Envoyé à l’ADV » : date d’envoi, ou raison de l’absence d’envoi', () => {
    expect(envoiAdv(LIGNE())).toEqual({ envoye: true, texte: dateHeure('2026-11-10T08:00:00Z') });
    expect(envoiAdv(LIGNE({ envoyeAdvLe: null, retireAs400: true }))).toEqual({ envoye: false, texte: "Non envoyé : client retiré de l'AS400" });
    expect(envoiAdv(LIGNE({ envoyeAdvLe: null }))).toEqual({ envoye: false, texte: 'Non envoyé' });
  });

  it('dates à l’heure de Paris', () => {
    expect(nbsp(dateHeure('2026-11-09T08:22:00Z'))).toBe('09/11/2026 09:22');
    expect(jourLong('2026-10-01T00:00:00Z')).toBe('1er octobre 2026');
    expect(jourLong('2026-10-15T00:00:00Z')).toBe('15 octobre 2026');
  });
});

describe('export CSV', () => {
  it('séparateur « ; », BOM UTF-8, CRLF, colonnes de l’écran', () => {
    const csv = versCsv([LIGNE()]);
    expect(csv.startsWith('﻿"Enseigne";"Code";"Ville";"Date";"Modifié par";"DR";"Envoyé à l\'ADV"\r\n')).toBe(true);
    expect(csv).toContain('"U EXPRESS 94 VINCENNES";"004701";"VINCENNES"');
    expect(csv.endsWith('\r\n')).toBe(true);
  });

  it('guillemets doublés et formules neutralisées (=, +, -, @)', () => {
    const csv = versCsv([LIGNE({ enseigne: '=HYPERLINK("http://x")', ville: '+33', modifiePar: '@cmd', dr: '-1+1', codeAs400: 'A"B' })]);
    expect(csv).toContain('"\'=HYPERLINK(""http://x"")"');
    expect(csv).toContain('"\'+33"');
    expect(csv).toContain('"\'@cmd"');
    expect(csv).toContain('"\'-1+1"');
    expect(csv).toContain('"A""B"');
  });
});

describe('modal « Clients passés inactifs »', () => {
  const rendre = (props: Parameters<typeof ClientsInactifs>[0] = {}) => nbsp(renderToStaticMarkup(createElement(ClientsInactifs, props)));

  it('fermé : seulement le bouton', () => {
    const html = rendre();
    expect(html).toContain('Clients passés inactifs');
    expect(html).not.toContain('role="dialog"');
  });

  it('ouvert avec des lignes : mois, nombre, export, colonnes, badge « Retiré de l’AS400 », envoi, mention de recensement', () => {
    const html = rendre({
      ouvertInitial: true,
      moisInitial: '2026-11',
      reponseInitiale: {
        data: {
          disponible: true,
          depuis: '2026-10-01',
          lignes: [
            LIGNE({ enseigne: 'AUCHAN SM 31 LHERM', ville: null, retireAs400: true, envoyeAdvLe: null, modifiePar: 'Elodie GENDRON', dr: 'Adrien RICHARD' }),
            LIGNE(),
          ],
        },
      },
    });
    expect(html).toContain('role="dialog"');
    expect(html).toContain('aria-modal="true"');
    expect(html).toContain('value="2026-11"');
    expect(html).toContain('2 client(s)');
    expect(html).toContain('Exporter CSV');
    for (const t of ['Enseigne', 'Code', 'Ville', 'Date', 'Modifié par', 'DR', "Envoyé à l'ADV"]) expect(html).toContain(t.replace("'", '&#x27;'));
    expect(html).toContain('Retiré de l&#x27;AS400');
    expect(html).toContain('Non envoyé : client retiré de l&#x27;AS400');
    expect(html).toContain('10/11/2026 09:00');
    expect(html).toContain('Seuls les passages en inactif effectués depuis le CRM à partir du 1er octobre 2026 sont recensés.');
  });

  it('historique non enregistré : le dit, sans liste vide ni mention de recensement, export désactivé', () => {
    const html = rendre({ ouvertInitial: true, reponseInitiale: { indisponible: true } });
    expect(html).toContain('n&#x27;est pas encore enregistré par le CRM');
    expect(html).not.toContain('client(s)');
    expect(html).not.toContain('Seuls les passages');
    expect(html).toMatch(/<button[^>]*disabled=""[^>]*>.*Exporter CSV/s);
  });

  it('mois sans passage et erreur : messages distincts', () => {
    expect(rendre({ ouvertInitial: true, reponseInitiale: { data: { disponible: true, depuis: null, lignes: [] } } })).toContain('Aucun client passé inactif sur ce mois.');
    const erreur = rendre({ ouvertInitial: true, reponseInitiale: { erreur: 'Accès refusé.' } });
    expect(erreur).toContain('role="alert"');
    expect(erreur).toContain('Accès refusé.');
  });
});
