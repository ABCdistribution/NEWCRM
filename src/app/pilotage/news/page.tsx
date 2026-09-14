import { getMe } from '@/lib/api';
import { NewsBoard } from '@/components/news-board';

export const metadata = { title: 'Les News — Helios' };

const CAN_MANAGE = ['ADMIN', 'DIRECTION', 'MARKETING'];

export default async function NewsPage() {
  const me = await getMe();
  const canManage = !!me && CAN_MANAGE.includes(me.role);
  return <NewsBoard canManage={canManage} me={me?.displayName ?? ''} />;
}
