import { ComingSoon } from '@/components/coming-soon';

export const metadata = { title: 'Mon agenda — Promoteurs' };

export default function AgendaPage() {
  return (
    <ComingSoon
      title="Mon agenda"
      description="Vue calendrier des passages planifiés et rendez-vous du commercial."
    />
  );
}
