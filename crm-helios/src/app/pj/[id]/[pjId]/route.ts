import { serverFetch } from '@/lib/api';

/** Relais authentifié de téléchargement d'une pièce jointe prospect. */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string; pjId: string }> }) {
  const { id, pjId } = await params;
  const res = await serverFetch(`/prospects/${id}/pieces-jointes/${pjId}`);
  if (!res.ok) return new Response(null, { status: res.status });
  const buf = await res.arrayBuffer();
  return new Response(buf, {
    headers: {
      'Content-Type': res.headers.get('content-type') ?? 'application/octet-stream',
      'Content-Disposition': res.headers.get('content-disposition') ?? 'attachment',
    },
  });
}
