import type { Metadata } from 'next';
import { LoginForm } from './login-form';
import { LoginSlider } from './login-slider';
import { cheminInterneSur } from '@/lib/chemin';

export const metadata: Metadata = {
  title: 'Connexion',
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string | string[] }>;
}) {
  const { from } = await searchParams;
  const target = cheminInterneSur(Array.isArray(from) ? from[0] : from);
  const year = new Date().getFullYear();

  return (
    // Thème violet (comme ABC Pilot) pour la page de connexion, commune aux deux espaces.
    <main data-espace="direction" className="flex min-h-screen w-full bg-white">
      <div className="flex min-h-screen w-full flex-col bg-white px-6 py-8 sm:px-12 lg:w-[55%] lg:px-20">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="ABC Group" className="h-16 w-16 rounded-xl object-contain" />

        <div className="flex flex-1 items-center justify-center">
          <div className="w-full max-w-sm">
            <h1 className="mb-8 text-3xl font-extrabold tracking-tight text-neutral-900">Bienvenue</h1>
            <LoginForm from={target} />
          </div>
        </div>

        <p className="text-center text-[11px] text-neutral-500 lg:text-left">
          © {year} ABC Distribution · CRM · ABcosmétique
        </p>
      </div>

      <div className="hidden lg:block lg:w-[45%]">
        <LoginSlider />
      </div>
    </main>
  );
}
