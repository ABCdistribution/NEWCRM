'use client';

import { useEffect, useRef, useState } from 'react';
import { ArrowLeftRight, Check, ChevronsUpDown, ExternalLink } from 'lucide-react';

export type SwitcherItem = {
  logo: string;
  nom: string;
  description: string;
  onClick?: () => void;
  externe?: boolean; // s'ouvre dans un nouvel onglet
  disabled?: boolean;
};

/**
 * Sélecteur d'univers / d'outils (façon Slack ou Notion) : un bouton compact
 * avec le logo et le nom de l'espace courant, qui déplie la liste des
 * destinations — bascule d'univers, outils externes.
 */
export function UniverseSwitcher({ actuel, items }: { actuel: { logo: string; nom: string; sousTitre: string }; items: SwitcherItem[] }) {
  const [ouvert, setOuvert] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ouvert) return;
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOuvert(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOuvert(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [ouvert]);

  return (
    <div ref={boxRef} className="relative mx-3 mb-3">
      <button
        type="button"
        onClick={() => setOuvert((o) => !o)}
        aria-expanded={ouvert}
        className="flex w-full items-center gap-2.5 rounded-xl border border-neutral-200 bg-white p-2 text-left transition hover:border-brand hover:bg-neutral-50 dark:border-navy-700 dark:bg-navy-950 dark:hover:border-accent dark:hover:bg-navy-800"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={actuel.logo} alt="" className="h-9 w-9 shrink-0 rounded-lg object-cover" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold leading-tight">{actuel.nom}</p>
          <p className="truncate text-[11px] text-neutral-400">{actuel.sousTitre}</p>
        </div>
        <ChevronsUpDown size={15} className="shrink-0 text-neutral-400" />
      </button>

      {ouvert ? (
        <div className="absolute left-0 right-0 top-full z-40 mt-1.5 overflow-hidden rounded-xl border border-neutral-200 bg-white shadow-xl dark:border-navy-700 dark:bg-navy-900">
          {/* Espace courant, coché */}
          <div className="flex items-center gap-2.5 border-b border-neutral-100 px-3 py-2.5 dark:border-navy-700">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={actuel.logo} alt="" className="h-8 w-8 shrink-0 rounded-lg object-cover" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{actuel.nom}</p>
              <p className="truncate text-[11px] text-neutral-400">Espace actuel</p>
            </div>
            <Check size={15} className="shrink-0 text-emerald-500" />
          </div>

          <ul className="p-1">
            {items.map((item) => (
              <li key={item.nom}>
                <button
                  type="button"
                  disabled={item.disabled}
                  onClick={() => {
                    if (item.disabled || !item.onClick) return;
                    setOuvert(false);
                    item.onClick();
                  }}
                  title={item.disabled ? `${item.nom} — bientôt disponible` : item.nom}
                  className="flex w-full items-center gap-2.5 rounded-lg px-2 py-2 text-left transition hover:bg-neutral-100 disabled:cursor-not-allowed disabled:opacity-45 dark:hover:bg-navy-800"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={item.logo} alt="" className="h-8 w-8 shrink-0 rounded-lg object-cover" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{item.nom}</p>
                    <p className="truncate text-[11px] text-neutral-400">{item.description}</p>
                  </div>
                  {item.externe ? (
                    <ExternalLink size={13} className="shrink-0 text-neutral-400" />
                  ) : item.disabled ? null : (
                    <ArrowLeftRight size={13} className="shrink-0 text-neutral-400" />
                  )}
                </button>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
}
