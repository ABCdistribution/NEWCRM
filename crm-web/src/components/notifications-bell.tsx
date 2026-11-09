'use client';

import { useEffect, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import { Bell, BellRing, CheckCheck } from 'lucide-react';
import { marquerLu, marquerToutLu } from '@/lib/notification-actions';
import { cheminCompatible } from '@/lib/chemin';
import type { NotificationItem } from '@/lib/api';

const TIME_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });

/** Cloche de notifications (menu) : badge non lues + panneau déroulant. */
export function NotificationsBell({
  nonLues,
  items,
}: {
  nonLues: number;
  items: NotificationItem[];
}) {
  const [open, setOpen] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const toutLu = () =>
    startTransition(async () => {
      const r = await marquerToutLu();
      setErreur(r.erreur);
    });

  const lire = (n: NotificationItem) => {
    if (n.luAt) return;
    startTransition(async () => {
      const r = await marquerLu(n.id);
      setErreur(r.erreur);
    });
  };

  return (
    <div ref={boxRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-haspopup="true"
        className="relative rounded-lg p-2 text-white transition hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-accent"
        aria-label={`Notifications (${nonLues} non lue${nonLues > 1 ? 's' : ''})`}
      >
        {nonLues > 0 ? <BellRing size={16} className="text-accent" /> : <Bell size={16} />}
        {nonLues > 0 ? (
          <span aria-hidden className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
            {nonLues > 9 ? '9+' : nonLues}
          </span>
        ) : null}
      </button>

      {open ? (
        <div className="absolute bottom-full left-0 z-50 mb-2 w-80 max-w-[calc(100vw-2rem)] rounded-xl border border-navy-600 bg-navy-900 text-neutral-100 shadow-xl max-md:bottom-auto max-md:left-auto max-md:right-0 max-md:top-full max-md:mb-0 max-md:mt-2">
          <div className="flex items-center justify-between border-b border-navy-700 px-3 py-2">
            <p className="text-xs font-semibold">Notifications</p>
            {nonLues > 0 ? (
              <button
                type="button"
                onClick={toutLu}
                disabled={pending}
                className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[11px] text-neutral-300 transition hover:text-white focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-60"
              >
                <CheckCheck size={11} />
                Tout marquer lu
              </button>
            ) : null}
          </div>
          {erreur ? (
            <p role="alert" className="border-b border-navy-700 px-3 py-2 text-xs text-red-300">
              {erreur}
            </p>
          ) : null}
          <ul className="max-h-80 overflow-y-auto p-1.5">
            {items.length === 0 ? (
              <li className="px-2 py-4 text-center text-xs text-neutral-300">Aucune notification.</li>
            ) : (
              items.map((n) => {
                const lien = cheminCompatible(n.lien);
                const contenu = (
                  <div className={`rounded-lg px-2.5 py-2 transition hover:bg-navy-800 ${n.luAt ? 'opacity-60' : ''}`}>
                    <p className="flex items-baseline gap-2 text-xs font-semibold">
                      {!n.luAt ? <span aria-label="Non lue" className="h-1.5 w-1.5 shrink-0 rounded-full bg-accent" /> : null}
                      {n.titre}
                      <span className="ml-auto shrink-0 text-[10px] font-normal text-neutral-300">
                        {TIME_FMT.format(new Date(n.createdAt))}
                      </span>
                    </p>
                    <p className="mt-0.5 text-[11px] leading-snug text-neutral-300">{n.message}</p>
                    {n.emetteur ? (
                      <p className="mt-0.5 text-[10px] text-neutral-300">par {n.emetteur.displayName}</p>
                    ) : null}
                  </div>
                );
                return (
                  <li key={n.id}>
                    {lien ? (
                      <Link
                        href={lien}
                        onClick={() => {
                          setOpen(false);
                          lire(n);
                        }}
                        className="block rounded-lg focus-visible:outline-2 focus-visible:outline-accent"
                      >
                        {contenu}
                      </Link>
                    ) : (
                      <button
                        type="button"
                        onClick={() => lire(n)}
                        className="block w-full rounded-lg text-left focus-visible:outline-2 focus-visible:outline-accent"
                      >
                        {contenu}
                      </button>
                    )}
                  </li>
                );
              })
            )}
          </ul>
        </div>
      ) : null}
    </div>
  );
}
