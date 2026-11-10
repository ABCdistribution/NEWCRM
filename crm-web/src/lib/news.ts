import { serverFetch, qs, type Role } from './api';

/** Une news telle que renvoyée par l'API (`/news`). Le contenu est du TEXTE BRUT. */
export type News = {
  id: string;
  titre: string;
  extrait: string;
  contenu: string;
  imageUrl: string | null;
  publiee: boolean;
  publieeAt: string | null;
  createdAt: string;
  updatedAt: string;
  auteur: { id: string; displayName: string };
};

export type NewsPage = { items: News[]; total: number; page: number; pageSize: number };

/**
 * Rôles autorisés à administrer les news : affichage des boutons ET garde des Server Actions (news-actions.ts,
 * exigerRole) ; l'API (@Roles(ADMIN, MARKETING)) reste juge.
 */
export const NEWS_ADMIN_ROLES: readonly Role[] = ['ADMIN', 'MARKETING'];

/** Liste paginée des news (les brouillons ne sont renvoyés qu'à ADMIN / MARKETING). */
export async function listNews(page: number, pageSize = 10): Promise<NewsPage | null> {
  try {
    const res = await serverFetch(`/news${qs({ page, pageSize })}`);
    if (!res.ok) return null;
    return (await res.json()) as NewsPage;
  } catch {
    return null;
  }
}
