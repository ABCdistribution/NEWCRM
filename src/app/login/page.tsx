import type { Metadata } from 'next';
import { Gauge, Users } from 'lucide-react';
import { LoginForm } from './login-form';

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
    <main className="flex min-h-screen w-full">
      {/* Colonne gauche — formulaire de connexion. */}
      <div className="flex w-full items-center justify-center bg-neutral-100 p-4 sm:p-6 lg:w-[45%] lg:p-12">
        <div className="w-full max-w-md rounded-3xl bg-white p-8 shadow-xl sm:p-10">
          {/* Marque */}
          <div className="mb-8 flex flex-col items-center text-center">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/abc-logo.jpg"
              alt="ABC Distribution"
              className="mb-5 h-16 w-auto rounded-xl object-contain"
            />
            <h1 className="text-3xl font-extrabold tracking-tight text-neutral-900">Bienvenue</h1>
            <p className="mt-1.5 text-sm text-neutral-500">CRM · ABcosmétique</p>
          </div>

          <LoginForm from={target} />

          {/* Deux tuiles — les deux univers du CRM. */}
          <div className="mt-6 grid grid-cols-2 gap-3">
            <div className="rounded-xl bg-neutral-100 p-3">
              <Gauge size={18} className="text-neutral-500" />
              <p className="mt-2 text-xs font-semibold text-neutral-700">Pilotage · Helios</p>
              <p className="text-[11px] text-neutral-400">Direction & encadrement</p>
            </div>
            <div className="rounded-xl bg-neutral-100 p-3">
              <Users size={18} className="text-neutral-500" />
              <p className="mt-2 text-xs font-semibold text-neutral-700">Terrain · Kratos</p>
              <p className="text-[11px] text-neutral-400">Promoteurs & commerciaux</p>
            </div>
          </div>

          <p className="mt-6 text-center text-[11px] text-neutral-400">
            © {year} ABC Distribution · CRM · ABcosmétique
          </p>
        </div>
      </div>

      {/* Colonne droite — artwork de marque (globe ABC + univers Kratos & Helios), masquée sur mobile. */}
      <div className="relative hidden overflow-hidden lg:block lg:w-[55%]">
        {/* Fond flouté pour remplir le panneau quel que soit son ratio. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/login-bg.webp"
          alt=""
          aria-hidden
          className="absolute inset-0 h-full w-full scale-110 object-cover blur-2xl"
        />
        {/* Artwork net, affiché entier sans recadrage. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/Login.png"
          alt=""
          aria-hidden
          className="absolute inset-0 h-full w-full object-contain p-8"
        />
      </div>
    </main>
  );
}
