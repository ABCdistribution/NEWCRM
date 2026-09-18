import type { Metadata } from 'next';
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
    <main
      className="flex min-h-screen w-full"
      style={{
        background: 'radial-gradient(80% 80% at 50% 40%, #16204a 0%, #0a1130 60%, #060a1f 100%)',
      }}
    >
      {/* Colonne gauche — formulaire de connexion. */}
      <div className="flex w-full items-center justify-center p-4 sm:p-6 lg:w-[45%] lg:p-12">
        <div className="w-full max-w-md rounded-3xl bg-white p-8 shadow-xl sm:p-10">
          {/* Marque */}
          <div className="mb-8 flex flex-col items-center text-center">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/logo-helios.png"
              alt="ABC Distribution"
              className="mb-5 h-28 w-auto rounded-2xl object-contain"
            />
            <h1 className="text-3xl font-extrabold tracking-tight text-neutral-900">Bienvenue</h1>
            <p className="mt-1.5 text-sm text-neutral-500">CRM · ABcosmétique</p>
          </div>

          <LoginForm from={target} />

          <p className="mt-6 text-center text-[11px] text-neutral-400">
            © {year} ABC Distribution · CRM · ABcosmétique
          </p>
        </div>
      </div>

      {/* Colonne droite — les trois univers flottent sur le dégradé nuit (masquée sur mobile). */}
      <div className="relative hidden overflow-hidden lg:block lg:w-[55%]">
        <style>{`
          @keyframes login-float {
            0%, 100% { transform: translateY(0) }
            50% { transform: translateY(-18px) }
          }
        `}</style>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logo-helios.png"
          alt=""
          aria-hidden
          className="absolute left-[16%] top-[12%] w-[38%] object-contain drop-shadow-[0_0_40px_rgba(124,102,255,.35)]"
          style={{ animation: 'login-float 6s ease-in-out infinite' }}
        />
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logo-sellios.png"
          alt=""
          aria-hidden
          className="absolute right-[8%] top-[38%] w-[38%] object-contain drop-shadow-[0_0_40px_rgba(59,130,246,.35)]"
          style={{ animation: 'login-float 7s ease-in-out 1.2s infinite' }}
        />
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/logo-ascendo.png"
          alt=""
          aria-hidden
          className="absolute bottom-[8%] left-[12%] w-[38%] object-contain drop-shadow-[0_0_40px_rgba(16,185,129,.35)]"
          style={{ animation: 'login-float 8s ease-in-out 2.4s infinite' }}
        />
      </div>
    </main>
  );
}
