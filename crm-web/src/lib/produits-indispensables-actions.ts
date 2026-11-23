'use server';

import { revalidatePath } from 'next/cache';
import { qs, serverFetch, type ArticleRow, type Paginated } from './api';
import { exigerRole, messageRefus } from './roles';
import { messageErreurApi } from './erreurs-api';
import {
  estUuid,
  lireChangements,
  ordreValide,
  texteRecherche,
  type ArticleTrouve,
} from './produits-indispensables';

/** Produits indispensables : ADMIN seul (même liste que l'écriture de l'API). */
const ADMIN = ['ADMIN'] as const;

const REFUSE = 'Accès refusé : action réservée aux administrateurs.';
const INJOIGNABLE = "Impossible de joindre l'API.";
const BASE = '/produits-indispensables';

const champ = (fd: FormData, nom: string): string => String(fd.get(nom) ?? '');

/** Appel d'écriture : statut vérifié, message français en cas d'échec. null = succès. */
async function ecrire(
  chemin: string,
  method: 'POST' | 'PATCH' | 'DELETE',
  corps: Record<string, unknown> | null,
  contexte: string,
): Promise<string | null> {
  let res: Response;
  try {
    res = await serverFetch(chemin, {
      method,
      ...(corps ? { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corps) } : {}),
    });
  } catch {
    return INJOIGNABLE;
  }
  if (!res.ok) return messageErreurApi(res, `admin produits indispensables : ${contexte}`);
  return null;
}

async function garde(): Promise<string | null> {
  try {
    await exigerRole(ADMIN);
    return null;
  } catch (e) {
    return messageRefus(e, REFUSE);
  }
}

/** Ajoute un article à la liste d'une enseigne (idempotent côté API). */
export async function ajouterProduitIndispensable(formData: FormData): Promise<string | null> {
  const refus = await garde();
  if (refus) return refus;
  const centraleId = champ(formData, 'centraleId');
  const articleId = champ(formData, 'articleId');
  if (!estUuid(centraleId)) return 'Enseigne invalide.';
  if (!estUuid(articleId)) return 'Article invalide.';
  const corps: Record<string, unknown> = { centraleId, articleId };
  if (formData.has('ordre')) {
    const ordre = ordreValide(champ(formData, 'ordre'));
    if (ordre === null) return 'Position invalide.';
    corps.ordre = ordre;
  }
  const erreur = await ecrire(BASE, 'POST', corps, 'ajout');
  if (!erreur) revalidatePath('/admin');
  return erreur;
}

/** Retire un produit de la liste (suppression logique côté API). */
export async function retirerProduitIndispensable(formData: FormData): Promise<string | null> {
  const refus = await garde();
  if (refus) return refus;
  const id = champ(formData, 'id');
  if (!estUuid(id)) return 'Produit invalide.';
  const erreur = await ecrire(`${BASE}/${encodeURIComponent(id)}`, 'DELETE', null, 'retrait');
  if (!erreur) revalidatePath('/admin');
  return erreur;
}

/**
 * Enregistre de nouvelles positions (`changements` : JSON [{ id, ordre }]), une requête par ligne, dans l'ordre. S'arrête
 * à la première erreur, et revalide dans tous les cas pour refléter ce qui a déjà été enregistré.
 */
export async function reordonnerProduitsIndispensables(formData: FormData): Promise<string | null> {
  const refus = await garde();
  if (refus) return refus;
  const { changements, erreur } = lireChangements(champ(formData, 'changements'));
  if (!changements) return erreur;
  let message: string | null = null;
  for (const { id, ordre } of changements) {
    message = await ecrire(`${BASE}/${encodeURIComponent(id)}`, 'PATCH', { ordre }, 'déplacement');
    if (message) break;
  }
  revalidatePath('/admin');
  return message;
}

export type ReponseRechercheArticles =
  | { data: ArticleTrouve[]; erreur?: undefined }
  | { data?: undefined; erreur: string };

/** Recherche d'articles par code, libellé, code-barres ou marque (`GET /articles?search=`), 10 résultats au plus. */
export async function rechercherArticles(texte: string): Promise<ReponseRechercheArticles> {
  const refus = await garde();
  if (refus) return { erreur: refus };
  const q = texteRecherche(texte);
  if (!q) return { data: [] };
  let res: Response;
  try {
    res = await serverFetch(`/articles${qs({ search: q, limit: 10 })}`);
  } catch {
    return { erreur: INJOIGNABLE };
  }
  if (!res.ok) return { erreur: await messageErreurApi(res, 'admin produits indispensables : recherche') };
  try {
    const corps = (await res.json()) as Paginated<ArticleRow>;
    if (!Array.isArray(corps.data)) throw new Error('réponse inattendue');
    return {
      data: corps.data.map((a) => ({
        id: a.id,
        codeAs400: a.codeAs400,
        libelle: a.libelle,
        gencode: a.gencode ?? null,
        actif: a.actif,
        marque: a.marque ? { nom: a.marque.nom } : null,
      })),
    };
  } catch {
    return { erreur: 'La recherche a renvoyé une réponse illisible.' };
  }
}
