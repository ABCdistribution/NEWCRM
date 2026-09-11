import type { Metadata } from 'next';
import { LoginForm } from './login-form';

export const metadata: Metadata = {
  title: 'Connexion — Helios',
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string }>;
}) {
  const { from } = await searchParams;
  const target = from && from.startsWith('/') && !from.startsWith('//') ? from : '/';

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#f5f3fb] p-4 dark:bg-navy-950">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center gap-2 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand text-lg font-bold text-white dark:bg-accent dark:text-brand">
            K
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-neutral-900 dark:text-neutral-50">
            Helios
          </h1>
          <p className="text-sm text-neutral-500">CRM Commercial · ABC Distribution</p>
        </div>

        <div className="dark rounded-2xl border border-neutral-200 bg-white shadow-card p-6 dark:border-navy-700 dark:bg-navy-950">
          <LoginForm from={target} />
        </div>
      </div>
    </main>
  );
}
