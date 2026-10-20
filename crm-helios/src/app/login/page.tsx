import type { Metadata } from 'next';
import { LoginForm } from './login-form';
import { LoginSlider } from './login-slider';

export const metadata: Metadata = {
  title: 'Connexion',
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string }>;
}) {
  const { from } = await searchParams;
  const target = from && from.startsWith('/') && !from.startsWith('//') ? from : '/';
  const year = new Date().getFullYear();

  return (
    <main className="flex min-h-screen w-full bg-white">
      {/* Formulaire de connexion — fond blanc, ~55 % de la page. */}
      <div className="flex min-h-screen w-full flex-col px-6 py-8 sm:px-12 lg:w-[55%] lg:px-20">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="ABC Group" className="h-16 w-16 rounded-xl object-contain" />

        <div className="flex flex-1 items-center justify-center">
          <div className="w-full max-w-sm">
            <h1 className="mb-8 text-3xl font-extrabold tracking-tight text-neutral-900">Bienvenue</h1>
            <LoginForm from={target} />
          </div>
        </div>

        <p className="text-center text-[11px] text-neutral-400 lg:text-left">
          © {year} ABC Distribution · CRM · ABcosmétique
        </p>
      </div>

      {/* Slider des univers — masqué sur mobile. */}
      <div className="hidden lg:block lg:w-[45%]">
        <LoginSlider />
      </div>
    </main>
  );
}
