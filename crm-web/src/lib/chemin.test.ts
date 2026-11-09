import { describe, expect, it } from 'vitest';
import { cheminCompatible, cheminInterneSur } from './chemin';

const ID = '123e4567-e89b-42d3-a456-426614174000';

/** Origine fictive de l'application : sert à vérifier, comme un navigateur, où mène un chemin renvoyé. */
const BASE = 'https://crm.exemple.test';

/** Valeur volontairement hors du contrat de type (venue d'une URL, d'un formulaire ou d'un JSON). */
const horsContrat = (valeur: unknown): string => valeur as string;

/** Origine atteinte quand le navigateur résout `chemin` depuis l'application (algorithme WHATWG, comme Node). */
const origineAtteinte = (chemin: string): string => new URL(chemin, BASE).origin;

/**
 * Corpus exhaustif (déterministe, sans hasard) : tous les enchaînements de 0 à 3 caractères « dangereux »
 * derrière chaque préfixe. Les caractères sont ceux qui font changer d'hôte ou d'en-tête :
 * slash, antislash, tabulation, LF, CR, NUL, DEL, deux-points, point, pourcent, arobase, ?, #, espace.
 */
function corpus(prefixes: string[]): string[] {
  const alphabet = ['/', '\\', '\t', '\n', '\r', '\u0000', '\u007f', ':', '.', 'a', '%', '@', '?', '#', ' '];
  let suffixes = [''];
  let niveau = [''];
  for (let longueur = 1; longueur <= 3; longueur++) {
    niveau = niveau.flatMap((s) => alphabet.map((c) => s + c));
    suffixes = [...suffixes, ...niveau];
  }
  return prefixes.flatMap((p) => suffixes.map((s) => p + s));
}

describe('cheminInterneSur', () => {
  describe('accepte les chemins internes (renvoyés à l\'identique)', () => {
    const acceptes = [
      { libelle: 'racine', entree: '/' },
      { libelle: 'page simple', entree: '/clients' },
      { libelle: 'page de détail', entree: `/clients/${ID}` },
      { libelle: 'chemin profond', entree: `/mon-equipe/promoteur/${ID}` },
      { libelle: 'avec requête', entree: '/commandes?page=2&search=abc' },
      { libelle: 'avec requête et ancre', entree: '/planning?semaine=2025-01-06#lundi' },
      { libelle: "onglet d'administration", entree: '/admin?onglet=utilisateurs' },
      { libelle: '/loginx : préfixe de mot, pas /login', entree: '/loginx' },
      { libelle: '/login-aide : préfixe de mot, pas /login', entree: '/login-aide' },
      { libelle: '/login plus bas dans le chemin', entree: '/clients/login' },
      { libelle: '« // » dans la requête (pas au début)', entree: '/clients?retour=//evil.com' },
      { libelle: 'URL absolue dans la requête', entree: '/clients?retour=http://evil.com' },
      { libelle: 'slashs encodés : texte de chemin inerte', entree: '/%2F%2Fevil.com' },
      { libelle: 'tabulation encodée : texte de chemin inerte', entree: '/%09/evil.com' },
      { libelle: 'arobase en début de segment (chemin, pas hôte)', entree: '/@evil.com' },
      { libelle: 'espace et accent (non bloqués)', entree: '/clients?search=café noir' },
      { libelle: 'longueur maximale autorisée (2000)', entree: `/${'a'.repeat(1999)}` },
    ];
    it.each(acceptes)('$libelle', ({ entree }) => {
      expect(cheminInterneSur(entree)).toBe(entree);
    });
  });

  describe('refuse et renvoie « / »', () => {
    const refuses = [
      { libelle: 'URL protocole-relative « //evil.com »', entree: '//evil.com' },
      { libelle: 'trois slashs', entree: '///evil.com' },
      { libelle: 'deux slashs seuls', entree: '//' },
      { libelle: 'antislash après le slash « /\\evil.com » (lu « // » par les navigateurs)', entree: '/\\evil.com' },
      { libelle: 'deux antislashs', entree: '/\\\\evil.com' },
      { libelle: 'antislash en milieu de chemin', entree: '/clients\\..\\evil' },
      { libelle: 'antislashs en tête', entree: '\\\\evil.com' },
      { libelle: 'tabulation après le slash (« /<TAB>/evil.com » devient « // »)', entree: '/\t/evil.com' },
      { libelle: 'tabulation en milieu de chemin', entree: '/cli\tents' },
      { libelle: 'retour chariot (CR)', entree: '/clients\r' },
      { libelle: "saut de ligne (LF) : injection d'en-tête", entree: '/clients\nSet-Cookie: x=1' },
      { libelle: 'CR + LF', entree: '/a\r\nLocation: http://evil.com' },
      { libelle: 'octet nul (NUL)', entree: '/clients\u0000' },
      { libelle: 'dernier caractère de contrôle C0 (U+001F)', entree: '/a\u001fb' },
      { libelle: 'caractère DEL (U+007F)', entree: '/a\u007fb' },
      { libelle: 'saut de ligne AVANT le slash', entree: '\n/clients' },
      { libelle: 'espace AVANT le slash', entree: ' /clients' },
      { libelle: '/login', entree: '/login' },
      { libelle: '/login/', entree: '/login/' },
      { libelle: '/login?x=1', entree: '/login?x=1' },
      { libelle: '/login#x', entree: '/login#x' },
      { libelle: '/login/x', entree: '/login/x' },
      { libelle: 'URL absolue http', entree: 'http://evil.com' },
      { libelle: 'URL absolue https avec chemin', entree: 'https://evil.com/clients' },
      { libelle: 'schéma en majuscules', entree: 'HTTPS://EVIL.COM' },
      { libelle: 'schéma javascript', entree: 'javascript:alert(1)' },
      { libelle: 'schéma data', entree: 'data:text/html,x' },
      { libelle: 'nom de domaine nu', entree: 'evil.com' },
      { libelle: 'chemin relatif sans slash', entree: 'clients' },
      { libelle: 'chemin relatif « ./ »', entree: './clients' },
      { libelle: 'requête seule', entree: '?x=1' },
      { libelle: 'ancre seule', entree: '#x' },
      { libelle: 'chaîne vide', entree: '' },
      { libelle: 'longueur 2001 (> 2000)', entree: `/${'a'.repeat(2000)}` },
    ];
    it.each(refuses)('$libelle', ({ entree }) => {
      expect(cheminInterneSur(entree)).toBe('/');
    });
  });

  describe('valeurs non-string', () => {
    it.each([
      ['null', null],
      ['undefined', undefined],
      ['nombre', 42],
      ['zéro', 0],
      ['true', true],
      ['false', false],
      ['NaN', Number.NaN],
      ['objet JSON vide', {}],
    ])('%s : « / » sans lever', (_libelle, valeur) => {
      expect(cheminInterneSur(horsContrat(valeur))).toBe('/');
    });

    // ANOMALIE (info) : hors contrat de type, mais atteignable : Next fournit un tableau quand ?from=a&from=b
    // est répété. L'appelant actuel (login/page.tsx) normalise avant l'appel ; la fonction elle-même n'est
    // pas « totale » (TypeError sur chemin.startsWith). Quand la garde `typeof chemin === 'string'` sera
    // ajoutée, ce test passera : il faudra alors remplacer it.fails par it.
    it.fails('un tableau (?from=/a&from=/b) : « / » au lieu d\'une TypeError', () => {
      expect(cheminInterneSur(horsContrat(['/clients', '/commandes']))).toBe('/');
    });
  });

  describe('propriété anti open-redirect (corpus exhaustif de caractères dangereux)', () => {
    const entrees = corpus(['', '/']);

    it(`le résultat est toujours « / » ou l'entrée, et reste sur l'origine de l'application (${entrees.length} cas)`, () => {
      const violations: string[] = [];
      for (const entree of entrees) {
        const sortie = cheminInterneSur(entree);
        const identique = sortie === '/' || sortie === entree;
        if (!identique || origineAtteinte(sortie) !== BASE) violations.push(JSON.stringify([entree, sortie]));
      }
      expect(violations).toEqual([]);
    });

    it('tout résultat autre que « / » est un chemin sans caractère de contrôle ni antislash, jamais /login', () => {
      const violations: string[] = [];
      for (const entree of entrees) {
        const sortie = cheminInterneSur(entree);
        if (sortie === '/') continue;
        const sain =
          sortie.startsWith('/') &&
          !sortie.startsWith('//') &&
          !/[\\\u0000-\u001f\u007f]/.test(sortie) &&
          !/^\/login(?:[/?#]|$)/.test(sortie);
        if (!sain) violations.push(JSON.stringify([entree, sortie]));
      }
      expect(violations).toEqual([]);
    });
  });
});

describe('cheminCompatible', () => {
  describe('rien à traduire', () => {
    it.each([
      ['null', null],
      ['undefined', undefined],
      ['chaîne vide', ''],
    ])('%s : null', (_libelle, lien) => {
      expect(cheminCompatible(lien)).toBeNull();
    });
  });

  describe('traduit les anciens liens (notifications déjà enregistrées par l\'API)', () => {
    const traductions = [
      { libelle: '/tournees', entree: '/tournees', attendu: '/planning' },
      { libelle: '/tournees avec requête', entree: '/tournees?semaine=2025-01-06', attendu: '/planning?semaine=2025-01-06' },
      { libelle: '/tournees avec ancre', entree: '/tournees#lundi', attendu: '/planning#lundi' },
      { libelle: '/tournees/ (slash final)', entree: '/tournees/', attendu: '/planning/' },
      { libelle: '/pilotage/ma-tournee', entree: '/pilotage/ma-tournee', attendu: '/planning' },
      {
        libelle: '/pilotage/ma-tournee avec requête',
        entree: '/pilotage/ma-tournee?semaine=2025-01-06',
        attendu: '/planning?semaine=2025-01-06',
      },
      { libelle: '/pilotage/ma-tournee/ (slash final)', entree: '/pilotage/ma-tournee/', attendu: '/planning/' },
      { libelle: '/pilotage seul : l\'accueil', entree: '/pilotage', attendu: '/' },
      { libelle: '/pilotage/ : l\'accueil', entree: '/pilotage/', attendu: '/' },
      { libelle: '/pilotage avec requête', entree: '/pilotage?x=1', attendu: '/?x=1' },
      { libelle: '/pilotage avec ancre', entree: '/pilotage#a', attendu: '/#a' },
      { libelle: '/pilotage/xxx : préfixe retiré', entree: '/pilotage/xxx', attendu: '/xxx' },
      { libelle: '/pilotage/admin', entree: '/pilotage/admin', attendu: '/admin' },
      {
        libelle: '/pilotage/admin avec onglet',
        entree: '/pilotage/admin?onglet=utilisateurs',
        attendu: '/admin?onglet=utilisateurs',
      },
      { libelle: '/pilotage/prospects/<id>', entree: `/pilotage/prospects/${ID}`, attendu: `/prospects/${ID}` },
      {
        libelle: '/pilotage/mon-equipe/<id>/planning',
        entree: `/pilotage/mon-equipe/${ID}/planning`,
        attendu: `/mon-equipe/${ID}/planning`,
      },
      { libelle: '/pilotage/ma-tourneeX : pas /pilotage/ma-tournee, préfixe retiré seulement', entree: '/pilotage/ma-tourneeX', attendu: '/ma-tourneeX' },
      // Règles spécifiques de la table REDIRECTIONS : le simple retrait du préfixe mènerait à une adresse inexistante.
      { libelle: '/pilotage/magasins : le suivi des clients', entree: '/pilotage/magasins', attendu: '/clients' },
      { libelle: '/pilotage/magasins avec requête', entree: '/pilotage/magasins?x=1', attendu: '/clients?x=1' },
      { libelle: '/pilotage/magasins/<id>/visite', entree: `/pilotage/magasins/${ID}/visite`, attendu: `/clients/${ID}/visite` },
      {
        libelle: '/pilotage/magasins/<id>/visite avec ancre',
        entree: `/pilotage/magasins/${ID}/visite#photos`,
        attendu: `/clients/${ID}/visite#photos`,
      },
      { libelle: '/pilotage/clients : la vue portefeuille', entree: '/pilotage/clients', attendu: '/clients?vue=portefeuille' },
      {
        libelle: '/pilotage/clients : requête de l\'ancien lien conservée',
        entree: '/pilotage/clients?search=abc&page=2',
        attendu: '/clients?search=abc&page=2&vue=portefeuille',
      },
      {
        libelle: '/pilotage/clients : la requête de la destination l\'emporte sur celle de l\'ancien lien',
        entree: '/pilotage/clients?vue=suivi&page=2',
        attendu: '/clients?vue=portefeuille&page=2',
      },
      { libelle: '/pilotage/clients/<id>', entree: `/pilotage/clients/${ID}`, attendu: `/clients/${ID}` },
      { libelle: '/pilotage/users : onglet de l\'administration', entree: '/pilotage/users', attendu: '/admin?onglet=utilisateurs' },
      { libelle: '/planification (ABC Sales)', entree: '/planification', attendu: '/planning-equipe' },
    ];
    it.each(traductions)('$libelle', ({ entree, attendu }) => {
      expect(cheminCompatible(entree)).toBe(attendu);
    });
  });

  describe('laisse passer les liens déjà au nouveau format et les faux amis', () => {
    it.each([
      { libelle: '/planning', entree: '/planning' },
      { libelle: 'racine', entree: '/' },
      { libelle: 'fiche client', entree: `/clients/${ID}` },
      { libelle: 'liste filtrée', entree: '/commandes?page=2' },
      { libelle: '/tournees/xxx : aucune règle de la table ne la redirige (adresse jamais servie)', entree: '/tournees/xxx' },
      { libelle: '/planificationX : préfixe de mot', entree: '/planificationX' },
      { libelle: '/tourneesX : préfixe de mot', entree: '/tourneesX' },
      { libelle: '/pilotagex : préfixe de mot', entree: '/pilotagex' },
      { libelle: '/pilotage-x : préfixe de mot', entree: '/pilotage-x' },
      { libelle: '/pilotage plus bas dans le chemin', entree: '/clients/pilotage/x' },
    ])('$libelle', ({ entree }) => {
      expect(cheminCompatible(entree)).toBe(entree);
    });
  });

  describe('refuse (null) ce qui n\'est pas un chemin interne sûr', () => {
    const refuses = [
      { libelle: '//evil.com', entree: '//evil.com' },
      { libelle: '/\\evil.com', entree: '/\\evil.com' },
      { libelle: 'URL absolue http', entree: 'http://evil.com' },
      { libelle: 'URL absolue https vers /pilotage', entree: 'https://evil.com/pilotage' },
      { libelle: 'schéma javascript', entree: 'javascript:alert(1)' },
      { libelle: 'nom de domaine nu', entree: 'evil.com' },
      { libelle: 'chemin relatif', entree: 'clients' },
      { libelle: 'LF', entree: '/clients\n' },
      { libelle: 'tabulation', entree: '/cli\tents' },
      { libelle: '/login', entree: '/login' },
      { libelle: '/login?x=1', entree: '/login?x=1' },
      // Le retrait du préfixe ne doit JAMAIS fabriquer un chemin dangereux :
      { libelle: '/pilotage//evil.com : le retrait du préfixe donnerait « //evil.com »', entree: '/pilotage//evil.com' },
      { libelle: '/pilotage/\\evil.com : le retrait du préfixe donnerait « /\\evil.com »', entree: '/pilotage/\\evil.com' },
      { libelle: '/pilotage/login : le retrait du préfixe donnerait /login', entree: '/pilotage/login' },
      { libelle: '/pilotage/login?from=/x', entree: '/pilotage/login?from=/x' },
      { libelle: '/pilotage + tabulation', entree: '/pilotage/\t/evil.com' },
      { libelle: '/tournees + CRLF', entree: '/tournees\r\nLocation: http://evil.com' },
      { libelle: '/pilotage/ma-tournee + NUL', entree: '/pilotage/ma-tournee\u0000' },
      { libelle: 'longueur 2001 sans préfixe à retirer', entree: `/${'a'.repeat(2000)}` },
    ];
    it.each(refuses)('$libelle', ({ entree }) => {
      expect(cheminCompatible(entree)).toBeNull();
    });
  });

  describe('propriété anti open-redirect (corpus exhaustif de caractères dangereux)', () => {
    const entrees = corpus([
      '',
      '/',
      '/pilotage',
      '/pilotage/ma-tournee',
      '/pilotage/clients',
      '/pilotage/magasins',
      '/tournees',
      '/planification',
    ]);

    it(`un résultat non nul reste sur l'origine de l'application et n'est jamais /login (${entrees.length} cas)`, () => {
      const violations: string[] = [];
      for (const entree of entrees) {
        const sortie = cheminCompatible(entree);
        if (sortie === null) continue;
        const sain =
          sortie.startsWith('/') &&
          origineAtteinte(sortie) === BASE &&
          !/[\\\u0000-\u001f\u007f]/.test(sortie) &&
          !/^\/login(?:[/?#]|$)/.test(sortie);
        if (!sain) violations.push(JSON.stringify([entree, sortie]));
      }
      expect(violations).toEqual([]);
    });
  });
});
