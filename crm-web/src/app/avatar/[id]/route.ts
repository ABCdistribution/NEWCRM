import { serverFetch } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TYPES_IMAGE = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);

const introuvable = (status = 404) =>
  new Response(null, { status, headers: { 'X-Content-Type-Options': 'nosniff' } });

/**
 * Proxy d'avatar : une balise <img> ne peut pas envoyer le JWT (cookie httpOnly).
 * Ce handler lit le cookie de session côté serveur et récupère la photo de l'API.
 * Seuls les types d'image courants sont relayés (jamais le Content-Type de l'API tel quel).
 */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID.test(id)) return introuvable();

  let res: Response;
  try {
    res = await serverFetch(`/users/${encodeURIComponent(id)}/photo`);
  } catch {
    return introuvable(502);
  }
  if (!res.ok) return introuvable();

  const type = (res.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
  if (!TYPES_IMAGE.has(type)) return introuvable();

  const buf = await res.arrayBuffer();
  return new Response(buf, {
    headers: {
      'Content-Type': type,
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'private, max-age=3600',
    },
  });
}
