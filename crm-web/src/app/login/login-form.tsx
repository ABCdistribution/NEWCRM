'use client';

import { useActionState, useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';
import { login, type LoginState } from '@/lib/auth-actions';

const initialState: LoginState = { error: null };

const CHAMP =
  'rounded-lg border border-transparent bg-neutral-100 px-3.5 py-3 text-neutral-900 outline-none transition placeholder:text-neutral-400 focus:border-brand focus:bg-white focus-visible:ring-2 focus-visible:ring-brand/40';

export function LoginForm({ from }: { from: string }) {
  const [state, formAction, pending] = useActionState(login, initialState);
  const [show, setShow] = useState(false);

  return (
    <form action={formAction} className="flex flex-col gap-4">
      <input type="hidden" name="from" value={from} />

      <div className="flex flex-col gap-1.5" suppressHydrationWarning>
        <label htmlFor="username" className="text-sm font-semibold text-neutral-800">
          Identifiant
        </label>
        <input
          id="username"
          name="username"
          type="text"
          autoComplete="username"
          autoCapitalize="none"
          spellCheck={false}
          required
          autoFocus
          suppressHydrationWarning
          placeholder="prénom.nom"
          className={CHAMP}
        />
      </div>

      <div className="flex flex-col gap-1.5" suppressHydrationWarning>
        <label htmlFor="password" className="text-sm font-semibold text-neutral-800">
          Mot de passe
        </label>
        <div className="relative" suppressHydrationWarning>
          <input
            id="password"
            name="password"
            type={show ? 'text' : 'password'}
            autoComplete="current-password"
            required
            suppressHydrationWarning
            placeholder="••••••••"
            className={`${CHAMP} w-full pr-11`}
          />
          <button
            type="button"
            onClick={() => setShow((v) => !v)}
            aria-label={show ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
            aria-pressed={show}
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-neutral-500 transition hover:text-neutral-700 focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand"
          >
            {show ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        </div>
      </div>

      {state.error ? (
        <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={pending}
        className="mt-2 inline-flex items-center justify-center rounded-lg bg-neutral-900 px-4 py-3 font-medium text-white transition hover:bg-neutral-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-60"
      >
        {pending ? 'Connexion…' : 'Se connecter'}
      </button>

      <p className="text-center text-xs text-neutral-500">
        Connexion via votre compte Active Directory ABC.
      </p>
    </form>
  );
}
