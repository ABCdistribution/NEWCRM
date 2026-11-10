import { Injectable } from '@nestjs/common';
import { Prisma, Role, User } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { codesRepresentantsDuPerimetre } from '../common/perimetre-codes.util';
import { perimetreEquipe } from '../common/perimetre-users.util';
import { ProspectsService } from '../prospection/prospects.service';
import { auteursDeVisitesVisibles } from '../visites/visites.service';

export type TypeResultat = 'clients' | 'commandes' | 'visites' | 'collaborateurs' | 'prospects' | 'produits';

/** Une ligne de résultat : le strict nécessaire pour l'afficher et construire le lien (les routes restent côté front). */
export interface Resultat {
  id: string;
  titre: string;
  detail: string | null;
  /** Collaborateurs : rôle (le front choisit la fiche à ouvrir). */
  role?: Role;
  /** Visites : client concerné (null pour une visite de prospect). */
  clientId?: string | null;
  /** Visites et produits : texte à passer à la liste de destination (?search=). */
  recherche?: string;
}

export interface GroupeResultats {
  type: TypeResultat;
  /** Nombre total de correspondances dans le périmètre (les `items` n'en montrent que quelques-unes). */
  total: number;
  items: Resultat[];
}

export interface RechercheGlobale {
  q: string;
  groupes: GroupeResultats[];
}

/** Lignes montrées par famille. */
const PAR_GROUPE = 5;
/** Mots pris en compte dans la saisie. */
const MOTS_MAX = 4;

/** Rôles qui ont l'écran Prospection (mêmes rôles que `@Roles` de ProspectsController). */
const ROLES_PROSPECTION: Role[] = [Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL, Role.DIRECTION, Role.ADMIN];

const contient = (mot: string) => ({ contains: mot, mode: 'insensitive' as const });

/** Chaque mot doit se retrouver dans l'un des champs : « auchan rouen » trouve l'enseigne Auchan à Rouen. */
function chaqueMot<T>(mots: string[], champs: ((mot: string) => T)[]): { OR: T[] }[] {
  return mots.map((mot) => ({ OR: champs.map((champ) => champ(mot)) }));
}

const dateFr = (d: Date | null | undefined) =>
  d ? new Date(d).toLocaleDateString('fr-FR', { timeZone: 'Europe/Paris' }) : null;

const joindre = (...parts: (string | null | undefined | false)[]) => parts.filter(Boolean).join(' · ') || null;

/**
 * Recherche générale (bandeau du haut) : clients, commandes, visites, collaborateurs, prospects et produits.
 *
 * Droits et périmètre, famille par famille (jamais plus large que les écrans correspondants, parfois plus strict) :
 *  - clients et commandes : codes représentants du périmètre (promoteur = lui, CS = ses promoteurs, DR = sa région,
 *    siège / direction / admin = tout). Pour les commandes c'est plus strict que `GET /commandes`, qui ne borne que le
 *    promoteur ;
 *  - visites : mêmes auteurs visibles que `GET /visites` (`auteursDeVisitesVisibles`) ;
 *  - collaborateurs : équipe encadrée (`perimetreEquipe`) ; promoteur, ADV et marketing n'en cherchent aucun ;
 *  - prospects : rôles de l'écran Prospection et périmètre de `ProspectsService.scope` ;
 *  - produits : catalogue, ouvert à tous les rôles comme `GET /articles`.
 * Les champs renvoyés sont limités à ce que les listes affichent déjà (ni e-mail, ni téléphone, ni montants).
 */
@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly prospects: ProspectsService,
  ) {}

  async rechercher(me: User, q: string): Promise<RechercheGlobale> {
    // Les jokers LIKE (% _ \) n'ont pas de sens ici et élargiraient la recherche à tout le périmètre : ils séparent les mots.
    const mots = q.replace(/[%_\\]/g, ' ').split(/\s+/).filter(Boolean).slice(0, MOTS_MAX);
    // Au moins 2 caractères utiles au total (le DTO ne compte que la saisie brute).
    if (mots.join('').length < 2) return { q, groupes: [] };

    // Codes représentants du périmètre : calculés une fois pour les clients et les commandes.
    const codes = await codesRepresentantsDuPerimetre(this.prisma, me);

    // Deux vagues de trois familles (6 requêtes chacune au plus) : une recherche ne doit pas occuper à elle seule le
    // pool de connexions (10) au détriment des autres écrans.
    const vague1 = await Promise.all([this.clients(mots, codes), this.commandes(mots, codes), this.visites(me, mots)]);
    const vague2 = await Promise.all([this.collaborateurs(me, mots), this.prospectsDuPerimetre(me, mots), this.produits(mots)]);
    const familles = [...vague1, ...vague2];
    return { q, groupes: familles.filter((g): g is GroupeResultats => g !== null && g.items.length > 0) };
  }

  private async clients(mots: string[], codes: string[] | null): Promise<GroupeResultats | null> {
    if (codes !== null && codes.length === 0) return null;
    const where: Prisma.ClientWhereInput = {
      deletedAt: null,
      AND: [
        ...(codes ? [{ OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }] }] : []),
        ...chaqueMot<Prisma.ClientWhereInput>(mots, [
          (m) => ({ enseigne: contient(m) }),
          (m) => ({ raisonSociale: contient(m) }),
          (m) => ({ codeAs400: contient(m) }),
          (m) => ({ ville: contient(m) }),
        ]),
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.client.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: { enseigne: 'asc' },
        select: { id: true, enseigne: true, raisonSociale: true, ville: true, codeAs400: true },
      }),
      this.prisma.client.count({ where }),
    ]);
    return {
      type: 'clients',
      total,
      items: rows.map((c) => ({ id: c.id, titre: c.enseigne || c.raisonSociale, detail: joindre(c.ville, c.codeAs400) })),
    };
  }

  private async commandes(mots: string[], codes: string[] | null): Promise<GroupeResultats | null> {
    if (codes !== null && codes.length === 0) return null;
    const where: Prisma.CommandeWhereInput = {
      AND: [
        ...(codes ? [{ idRepr: { in: codes } }] : []),
        ...chaqueMot<Prisma.CommandeWhereInput>(mots, [
          (m) => ({ numero: contient(m) }),
          (m) => ({ raisonSocialeCmd: contient(m) }),
          (m) => ({ client: { is: { enseigne: contient(m) } } }),
          (m) => ({ client: { is: { codeAs400: contient(m) } } }),
        ]),
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.commande.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: [{ dateCommande: 'desc' }, { numero: 'desc' }],
        select: {
          id: true,
          numero: true,
          dateCommande: true,
          dateAnnulation: true,
          raisonSocialeCmd: true,
          client: { select: { enseigne: true } },
        },
      }),
      this.prisma.commande.count({ where }),
    ]);
    return {
      type: 'commandes',
      total,
      items: rows.map((c) => ({
        id: c.id,
        titre: `Commande ${c.numero}`,
        detail: joindre(c.client?.enseigne ?? c.raisonSocialeCmd, dateFr(c.dateCommande), c.dateAnnulation && 'annulée'),
      })),
    };
  }

  private async visites(me: User, mots: string[]): Promise<GroupeResultats | null> {
    // null = pas de filtre d'auteur (siège, direction, admin, ADV, marketing), comme `GET /visites`.
    const auteurs = auteursDeVisitesVisibles(me);
    const where: Prisma.VisiteWhereInput = {
      deletedAt: null,
      ...(auteurs ? { promoteur: auteurs } : {}),
      AND: chaqueMot<Prisma.VisiteWhereInput>(mots, [
        (m) => ({ client: { is: { enseigne: contient(m) } } }),
        (m) => ({ client: { is: { ville: contient(m) } } }),
        (m) => ({ client: { is: { codeAs400: contient(m) } } }),
        (m) => ({ promoteur: { is: { displayName: contient(m) } } }),
      ]),
    };
    const [rows, total] = await Promise.all([
      this.prisma.visite.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          createdAt: true,
          client: { select: { id: true, enseigne: true, ville: true } },
          promoteur: { select: { displayName: true } },
        },
      }),
      this.prisma.visite.count({ where }),
    ]);
    return {
      type: 'visites',
      total,
      items: rows.map((v) => ({
        id: v.id,
        titre: `Visite ${v.client?.enseigne ?? 'prospect'}`,
        detail: joindre(v.promoteur.displayName, dateFr(v.createdAt)),
        clientId: v.client?.id ?? null,
        ...(v.client?.enseigne ? { recherche: v.client.enseigne } : {}),
      })),
    };
  }

  private async collaborateurs(me: User, mots: string[]): Promise<GroupeResultats | null> {
    const equipe = perimetreEquipe(me);
    if (equipe === null) return null; // promoteur, ADV, marketing : pas d'équipe à chercher
    const where: Prisma.UserWhereInput = {
      isActive: true,
      AND: [
        equipe,
        ...chaqueMot<Prisma.UserWhereInput>(mots, [
          (m) => ({ displayName: contient(m) }),
          (m) => ({ username: contient(m) }),
          (m) => ({ poste: contient(m) }),
          (m) => ({ idRepr: contient(m) }),
        ]),
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: { displayName: 'asc' },
        select: { id: true, displayName: true, role: true, poste: true, idRepr: true },
      }),
      this.prisma.user.count({ where }),
    ]);
    return {
      type: 'collaborateurs',
      total,
      items: rows.map((u) => ({
        id: u.id,
        titre: u.displayName,
        detail: joindre(u.poste, u.idRepr && `code ${u.idRepr}`),
        role: u.role,
      })),
    };
  }

  private async prospectsDuPerimetre(me: User, mots: string[]): Promise<GroupeResultats | null> {
    if (!ROLES_PROSPECTION.includes(me.role)) return null;
    const where: Prisma.ProspectWhereInput = {
      deletedAt: null,
      AND: [
        this.prospects.scope(me).where,
        ...chaqueMot<Prisma.ProspectWhereInput>(mots, [
          (m) => ({ enseigne: contient(m) }),
          (m) => ({ raisonSociale: contient(m) }),
          (m) => ({ ville: contient(m) }),
        ]),
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.prospect.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: { enseigne: 'asc' },
        select: { id: true, enseigne: true, raisonSociale: true, ville: true },
      }),
      this.prisma.prospect.count({ where }),
    ]);
    return {
      type: 'prospects',
      total,
      items: rows.map((p) => ({ id: p.id, titre: p.enseigne || p.raisonSociale, detail: p.ville })),
    };
  }

  private async produits(mots: string[]): Promise<GroupeResultats> {
    const where: Prisma.ArticleWhereInput = {
      deletedAt: null,
      AND: chaqueMot<Prisma.ArticleWhereInput>(mots, [
        (m) => ({ codeAs400: contient(m) }),
        (m) => ({ libelle: contient(m) }),
        (m) => ({ gencode: contient(m) }),
        (m) => ({ marque: { is: { nom: contient(m) } } }),
      ]),
    };
    const [rows, total] = await Promise.all([
      this.prisma.article.findMany({
        where,
        take: PAR_GROUPE,
        orderBy: { libelle: 'asc' },
        select: { id: true, codeAs400: true, libelle: true, marque: { select: { nom: true } } },
      }),
      this.prisma.article.count({ where }),
    ]);
    return {
      type: 'produits',
      total,
      items: rows.map((a) => ({
        id: a.id,
        titre: a.libelle,
        detail: joindre(a.marque?.nom, a.codeAs400),
        recherche: a.codeAs400,
      })),
    };
  }
}
