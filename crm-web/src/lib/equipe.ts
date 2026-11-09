// Chargement serveur des données de « Mon équipe » (serverFetch uniquement — jamais d'appel depuis le navigateur).
// Les droits restent décidés par l'API : ici on ne fait que présenter ce qu'elle renvoie.
import {
  getDashboardDirection,
  getRapportDetail,
  idReprVariants,
  listPlannings,
  listRapports,
  qs,
  serverFetch,
  type ClientRow,
  type CommandeRow,
  type DashboardDirection,
  type Paginated,
  type UserRow,
  type VisiteActivite,
} from './api';
import {
  ajouterJours,
  calculerEcarts,
  chefDe,
  iso,
  lundiDe,
  zoneDe,
  type CsCarte,
  type PromoLigne,
} from './equipe-utils';
import { aujourdhuiParis } from './planning-dates';

/** Tous les utilisateurs visibles par le rôle courant (l'API pagine à 20) ; null si l'API est injoignable. */
export async function listerUtilisateurs(): Promise<UserRow[] | null> {
  const users: UserRow[] = [];
  try {
    for (let p = 1; p <= 30; p++) {
      const res = await serverFetch(`/users${qs({ page: p, limit: 20 })}`);
      if (!res.ok) return p === 1 ? null : users;
      const page = (await res.json()) as Paginated<UserRow>;
      users.push(...page.data);
      if (users.length >= page.total || page.data.length < 20) break;
    }
    return users;
  } catch {
    return null;
  }
}

/** Récupère une liste paginée : page 1, puis les suivantes en parallèle (dans la limite de `maxPages`). */
async function pagesParallele<T>(chemin: (page: number) => string, maxPages: number): Promise<{ lignes: T[]; tronque: boolean } | null> {
  try {
    const r1 = await serverFetch(chemin(1));
    if (!r1.ok) return null;
    const p1 = (await r1.json()) as Paginated<T>;
    const lignes = [...p1.data];
    const taille = p1.limit || p1.data.length || 1;
    const nbPages = Math.max(1, Math.ceil(p1.total / taille));
    const suite = await Promise.all(
      Array.from({ length: Math.max(0, Math.min(nbPages, maxPages) - 1) }, async (_, i) => {
        try {
          const r = await serverFetch(chemin(i + 2));
          return r.ok ? ((await r.json()) as Paginated<T>).data : [];
        } catch {
          return [];
        }
      }),
    );
    for (const s of suite) lignes.push(...s);
    return { lignes, tronque: nbPages > maxPages };
  } catch {
    return null;
  }
}

/** Nombre de clients d'un code représentant (lit `total`, page minimale). */
async function compterClients(repr: string | null): Promise<number | null> {
  if (!repr) return null;
  try {
    const res = await serverFetch(`/clients${qs({ repr, limit: 1 })}`);
    if (!res.ok) return null;
    return ((await res.json()) as Paginated<ClientRow>).total;
  } catch {
    return null;
  }
}

/** Portefeuille complet d'un promoteur (pour le sélecteur de client). */
export async function clientsDuPromoteur(repr: string | null): Promise<ClientRow[]> {
  if (!repr) return [];
  const r = await pagesParallele<ClientRow>((p) => `/clients${qs({ repr, limit: 100, page: p })}`, 10);
  return (r?.lignes ?? []).sort((a, b) => a.enseigne.localeCompare(b.enseigne));
}

/**
 * Visites d'un utilisateur. L'API ne filtre pas par utilisateur : on parcourt les visites les plus récentes (30 par page,
 * 10 pages au plus) et on filtre ici. Avec un client choisi, la recherche serveur (code client) réduit le parcours.
 */
export async function visitesDe(userId: string, client?: ClientRow | null): Promise<{ lignes: VisiteActivite[]; tronque: boolean } | null> {
  const r = await pagesParallele<VisiteActivite>((p) => `/visites${qs({ page: p, search: client?.codeAs400 })}`, 10);
  if (!r) return null;
  const lignes = r.lignes
    .filter((v) => v.promoteur?.id === userId && (!client || v.client?.id === client.id))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return { lignes, tronque: r.tronque };
}

/**
 * Commandes d'un code représentant. L'API ne filtre pas par représentant : on parcourt les commandes les plus récentes
 * (100 par page, 10 pages au plus) et on filtre ici ; avec un client choisi, la recherche serveur réduit le parcours.
 */
export async function commandesDe(idRepr: string | null, client?: ClientRow | null): Promise<{ lignes: CommandeRow[]; tronque: boolean } | null> {
  if (!idRepr) return { lignes: [], tronque: false };
  const variantes = idReprVariants(idRepr);
  const r = await pagesParallele<CommandeRow>((p) => `/commandes${qs({ page: p, limit: 100, search: client?.codeAs400 })}`, 10);
  if (!r) return null;
  const lignes = r.lignes.filter(
    (c) => c.idRepr != null && variantes.includes(c.idRepr) && (!client || c.client?.id === client.id),
  );
  return { lignes, tronque: r.tronque };
}

/** Nombre maximal de promoteurs traités en même temps (2 appels API chacun : clients + planning). */
const LOT_PROMOTEURS = 8;
/** Nombre maximal de chefs de secteur traités en même temps (1 appel API chacun : détail du rapport). */
const LOT_CHEFS = 10;

/**
 * Applique `fn` à chaque élément par lots de `taille` appels simultanés (l'ordre est conservé). L'API n'a pas de
 * limiteur de débit : un Promise.all sur tout le périmètre (150 promoteurs = 300 requêtes) saturerait son pool de connexions.
 */
async function parLots<T, R>(elements: readonly T[], taille: number, fn: (element: T) => Promise<R>): Promise<R[]> {
  const resultats: R[] = [];
  for (let i = 0; i < elements.length; i += taille) {
    resultats.push(...(await Promise.all(elements.slice(i, i + taille).map(fn))));
  }
  return resultats;
}

/**
 * Lignes « promoteur » (CA / objectif, visites de la semaine et du jour, nombre de clients) pour une liste de promoteurs.
 * Les appels par promoteur sont traités par lots (LOT_PROMOTEURS). Une valeur manquante parce qu'une requête a échoué
 * (et non parce qu'elle est absente des données) rend la ligne `incomplet`, pour que l'écran le signale.
 */
export async function lignesPromoteurs(promoteurs: UserRow[], chefs: UserRow[]): Promise<PromoLigne[]> {
  // « Maintenant » À PARIS (fuseau de l'API) : la semaine et le mois courants ne dépendent pas du fuseau du serveur.
  const now = aujourdhuiParis();
  const lundi = lundiDe(now);
  const aujourdhui = iso(now);
  const data: DashboardDirection | null = await getDashboardDirection(now.getFullYear(), now.getMonth() + 1);
  const perfParId = new Map((data?.classement ?? []).filter((c) => c.userId).map((c) => [c.userId as string, c]));
  const perfParRepr = new Map((data?.classement ?? []).map((c) => [c.idRepr, c]));

  return parLots(promoteurs, LOT_PROMOTEURS, async (u) => {
    const [nbClients, plan] = await Promise.all([
      compterClients(u.idRepr),
      listPlannings(u.id, iso(lundi), iso(ajouterJours(lundi, 7))),
    ]);
    const perf =
      perfParId.get(u.id) ?? (u.idRepr ? idReprVariants(u.idRepr).map((v) => perfParRepr.get(v)).find(Boolean) : undefined);
    const jour = plan?.filter((e) => e.datePassage.slice(0, 10) === aujourdhui) ?? null;
    const cs = chefDe(u, chefs);
    return {
      id: u.id,
      nom: u.displayName,
      csId: cs?.id ?? null,
      csNom: cs?.displayName ?? u.directeur?.displayName ?? null,
      regionNom: u.region?.nom ?? cs?.region?.nom ?? null,
      nbClients,
      ca: perf?.ca ?? null,
      objectif: perf?.objectif ?? null,
      visitesPrevues: plan ? plan.length : null,
      visitesFaites: plan ? plan.filter((e) => e.fait).length : null,
      jourPrevues: jour ? jour.length : null,
      jourFaites: jour ? jour.filter((e) => e.fait).length : null,
      // Planning ou tableau de bord muet, ou comptage des clients en échec alors que le promoteur a un code représentant.
      incomplet: plan === null || data === null || (!!u.idRepr && nbClients === null),
    } satisfies PromoLigne;
  });
}

/**
 * Cartes des chefs de secteur (vue du directeur régional) : état de la semaine, écarts, CA / objectif de l'équipe.
 * Les détails de rapport sont demandés par lots (LOT_CHEFS).
 */
export async function cartesChefs(chefs: UserRow[], promos: PromoLigne[]): Promise<CsCarte[]> {
  const semaine = iso(lundiDe(aujourdhuiParis()));
  const liste = await listRapports(semaine);
  const parUser = new Map((liste?.auteurs ?? []).map((a) => [a.userId, a]));
  return parLots(chefs, LOT_CHEFS, async (c) => {
    const equipe = promos.filter((p) => p.csId === c.id);
    const a = parUser.get(c.id);
    const detail = a ? await getRapportDetail(c.id, semaine) : null;
    const somme = (f: (p: PromoLigne) => number | null) =>
      equipe.some((p) => f(p) != null) ? equipe.reduce((s, p) => s + (f(p) ?? 0), 0) : null;
    return {
      id: c.id,
      nom: c.displayName,
      secteur: zoneDe(c),
      regionNom: c.region?.nom ?? null,
      nbPromoteurs: equipe.length,
      statut: a?.statut ?? null,
      prevuRenseigne: a ? !a.previsionNonRenseignee : null,
      nbPrevues: a?.nbPrevues ?? null,
      nbRealisees: a?.nbRealisees ?? null,
      nbFaites: a?.nbFaites ?? null,
      ecarts: detail ? calculerEcarts(detail.prevue, detail.realisee) : null,
      ca: somme((p) => p.ca),
      objectif: somme((p) => p.objectif),
      // Liste des rapports ou détail du rapport de ce chef indisponible, ou chiffres d'un de ses promoteurs incomplets.
      incomplet: liste === null || (a != null && detail === null) || equipe.some((p) => p.incomplet),
    } satisfies CsCarte;
  });
}
