import { getMe } from '@/lib/api';
import { listNews, NEWS_ADMIN_ROLES } from '@/lib/news';
import { NewsBoard } from '@/components/news-board';

export const metadata = { title: 'Les News — Direction commerciale' };

export default async function NewsPage({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  const sp = await searchParams;
  const page = Math.max(1, Math.floor(Number(sp.page)) || 1);
  const [me, data] = await Promise.all([getMe(), listNews(page)]);

  if (!data) {
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-2xl font-bold">Les News</h1>
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
          Impossible de charger les news. L&apos;API est-elle démarrée ?
        </p>
      </div>
    );
  }
  return <NewsBoard data={data} canManage={!!me && NEWS_ADMIN_ROLES.includes(me.role)} />;
}
