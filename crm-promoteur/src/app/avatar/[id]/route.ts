import { serverFetch } from '@/lib/api';

/**
 * Proxy d'avatar : une balise <img> ne peut pas envoyer le JWT (cookie httpOnly).
 * Ce handler lit le cookie de session côté serveur et récupère la photo de l'API.
 */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const res = await serverFetch(`/users/${id}/photo`);
  if (!res.ok) return new Response(null, { status: 404 });

  const buf = await res.arrayBuffer();
  return new Response(buf, {
    headers: {
      'Content-Type': res.headers.get('content-type') ?? 'image/jpeg',
      'Cache-Control': 'private, max-age=3600',
    },
  });
}
