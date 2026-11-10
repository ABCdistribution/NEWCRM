import { ComingSoon } from '@/components/coming-soon';
import { requireRole } from '@/lib/roles';

export const metadata = { title: 'Mon agenda' };

export default async function AgendaPage() {
  const acces = await requireRole(['COMMERCIAL', 'ADV']);
  if (acces.refuse) return acces.refuse;
  return (
    <ComingSoon
      title="Mon agenda"
      description="Vue calendrier des passages planifiés et rendez-vous du commercial."
    />
  );
}
