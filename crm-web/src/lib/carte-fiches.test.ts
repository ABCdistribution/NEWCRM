import { describe, expect, it } from 'vitest';
import { lireFichierApp, lireGarde } from '@/test/gardes-pages';
import { PAGES } from '@/test/pages-reelles';
import { peutOuvrirFicheChefSecteur, peutOuvrirFichePromoteur } from './carte-fiches';
import { ENCADREMENT, TERRAIN, TOUS_ROLES, type Role } from './roles';

// Aucun mock : les rôles sont les vrais ; seul le disque (src/app) est lu pour relire les gardes des pages.

const connus = { TOUS_ROLES, ENCADREMENT, TERRAIN };

/** Rôles de la garde `requireRole` de la page d'une URL de (app) ; erreur explicite si elle n'est pas lisible. */
function rolesDeLaPage(url: string): string[] {
  const page = PAGES.find((p) => p.groupes[0] === 'app' && p.url === url);
  if (!page) throw new Error(`aucune page ${url} dans (app)`);
  const garde = lireGarde(lireFichierApp(page.fichier), connus);
  if ('erreur' in garde) throw new Error(`${page.fichier} : ${garde.erreur}`);
  return garde.roles;
}

const rolesAutorises = (peut: (role: Role) => boolean): string[] => [...TOUS_ROLES].filter(peut).sort();

describe('liens de la carte d\'accueil vers les fiches « Mon équipe »', () => {
  it('fiche chef de secteur : mêmes rôles que la garde de /mon-equipe/[id]', () => {
    expect(rolesAutorises(peutOuvrirFicheChefSecteur)).toEqual(rolesDeLaPage('/mon-equipe/[id]'));
  });

  it('fiche promoteur : mêmes rôles que la garde de /mon-equipe/promoteur/[id]', () => {
    expect(rolesAutorises(peutOuvrirFichePromoteur)).toEqual(rolesDeLaPage('/mon-equipe/promoteur/[id]'));
  });

  it("DIRECTION ne reçoit aucun lien vers une fiche (il mènerait à « Accès refusé »)", () => {
    expect(peutOuvrirFicheChefSecteur('DIRECTION')).toBe(false);
    expect(peutOuvrirFichePromoteur('DIRECTION')).toBe(false);
  });

  it('ADMIN et DIRECTEUR_REGIONAL ouvrent les deux fiches ; le chef de secteur seulement celle du promoteur', () => {
    for (const role of ['ADMIN', 'DIRECTEUR_REGIONAL'] as const) {
      expect(peutOuvrirFicheChefSecteur(role)).toBe(true);
      expect(peutOuvrirFichePromoteur(role)).toBe(true);
    }
    expect(peutOuvrirFicheChefSecteur('CHEF_SECTEUR')).toBe(false);
    expect(peutOuvrirFichePromoteur('CHEF_SECTEUR')).toBe(true);
  });

  it("les rôles terrain et MARKETING n'ouvrent aucune fiche", () => {
    for (const role of ['COMMERCIAL', 'ADV', 'MARKETING'] as const) {
      expect(peutOuvrirFicheChefSecteur(role)).toBe(false);
      expect(peutOuvrirFichePromoteur(role)).toBe(false);
    }
  });
});
