import { serverFetch } from '@/lib/api';
import { ENCADREMENT, ErreurServiceIndisponible, exigerRole } from '@/lib/roles';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Types relayés tels quels ; tout autre type est servi en octet-stream (téléchargement forcé). */
const TYPES_SURS = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'text/plain',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);

const reponseVide = (status: number) =>
  new Response(null, { status, headers: { 'X-Content-Type-Options': 'nosniff' } });

/**
 * Relais authentifié de téléchargement d'une pièce jointe prospect (le JWT est en cookie httpOnly).
 * Ici : rôle de l'encadrement exigé (comme la fiche prospect, seule à porter ce lien, et les Server Actions
 * des prospects), ids UUID, types sûrs, nosniff, téléchargement forcé (attachment).
 * Le filtrage de périmètre reste décidé par l'API : le contrôle de rôle ci-dessous est une défense en
 * profondeur, il ne le remplace pas. Un rôle refusé ou une session absente reçoivent le même 404.
 */
export async function GET(_req: Request, { params }: { params: Promise<{ id: string; pjId: string }> }) {
  const { id, pjId } = await params;
  if (!UUID.test(id) || !UUID.test(pjId)) return reponseVide(404);

  try {
    await exigerRole(ENCADREMENT);
  } catch (e) {
    return reponseVide(e instanceof ErreurServiceIndisponible ? 503 : 404);
  }

  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(id)}/pieces-jointes/${encodeURIComponent(pjId)}`);
  } catch {
    return reponseVide(502);
  }
  if (!res.ok) return reponseVide(res.status);

  const brut = (res.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase();
  const type = TYPES_SURS.has(brut) ? brut : 'application/octet-stream';
  const disposition = res.headers.get('content-disposition');
  const buf = await res.arrayBuffer();
  return new Response(buf, {
    headers: {
      'Content-Type': type,
      // Toujours en téléchargement : jamais d'affichage en ligne d'un fichier fourni par un utilisateur.
      'Content-Disposition': disposition?.toLowerCase().startsWith('attachment') ? disposition : 'attachment',
      'X-Content-Type-Options': 'nosniff',
      'Cache-Control': 'private, no-store',
    },
  });
}
