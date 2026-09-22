'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Bell, BellRing, CheckCheck } from 'lucide-react';
import { marquerToutLu } from '@/lib/notification-actions';
import type { NotificationItem } from '@/lib/api';

const TIME_FMT = new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });

/** Cloche de notifications (sidebar) : badge non lues + panneau déroulant. */
export function NotificationsBell({
  nonLues,
  items,
}: {
  nonLues: number;
  items: NotificationItem[];
}) {
  const [open, setOpen] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  return (
    <div ref={boxRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="relative rounded-lg p-2 text-neutral-400 transition hover:bg-neutral-100 hover:text-neutral-700 dark:hover:bg-navy-800 dark:hover:text-neutral-200"
        aria-label={`Notifications (${nonLues} non lue${nonLues > 1 ? 's' : ''})`}
      >
        {nonLues > 0 ? <BellRing size={16} className="text-accent" /> : <Bell size={16} />}
        {nonLues > 0 ? (
          <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
            {nonLues > 9 ? '9+' : nonLues}
          </span>
        ) : null}
      </button>

      {open ? (
        <div className="absolute bottom-full left-0 z-40 mb-2 w-80 rounded-xl border border-neutral-200 bg-white shadow-xl dark:border-navy-600 dark:bg-navy-900">
          <div className="flex items-center justify-between border-b border-neutral-100 px-3 py-2 dark:border-navy-700">
            <p className="text-xs font-semibold">Notifications</p>
            {nonLues > 0 ? (
              <form action={marquerToutLu}>
                <button
                  type="submit"
                  className="inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] text-neutral-400 transition hover:text-accent"
                >
                  <CheckCheck size={11} />
                  Tout marquer lu
                </button>
              </form>
            ) : null}
          </div>
          <ul className="max-h-80 overflow-y-auto p-1.5">
            {items.length === 0 ? (
              <li className="px-2 py-4 text-center text-xs text-neutral-400">Aucune notification.</li>
            ) : (
              items.map((n) => {
                const contenu = (
                  <div className={`rounded-lg px-2.5 py-2 transition hover:bg-neutral-100 dark:hover:bg-navy-800 ${n.luAt ? 'opacity-55' : ''}`}>
                    <p className="flex items-baseline gap-2 text-xs font-semibold">
                      {!n.luAt ? <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-accent" /> : null}
                      {n.titre}
                      <span className="ml-auto shrink-0 text-[9px] font-normal text-neutral-500">
                        {TIME_FMT.format(new Date(n.createdAt))}
                      </span>
                    </p>
                    <p className="mt-0.5 text-[11px] leading-snug text-neutral-400">{n.message}</p>
                    {n.emetteur ? (
                      <p className="mt-0.5 text-[9px] text-neutral-500">par {n.emetteur.displayName}</p>
                    ) : null}
                  </div>
                );
                return (
                  <li key={n.id}>
                    {n.lien ? (
                      <Link href={n.lien} onClick={() => setOpen(false)}>
                        {contenu}
                      </Link>
                    ) : (
                      contenu
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
