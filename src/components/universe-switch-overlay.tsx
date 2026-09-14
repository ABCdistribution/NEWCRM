'use client';

import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';

/**
 * Voile plein écran affiché pendant la bascule d'univers (Helios ↔ Kratos) :
 * le logo de l'univers quitté s'efface pendant que celui de la destination
 * arrive et pulse jusqu'à ce que la navigation aboutisse.
 */
export function UniverseSwitchOverlay({
  fromSrc,
  toSrc,
  toName,
}: {
  fromSrc: string;
  toSrc: string;
  toName: string;
}) {
  // Portal : le rendu doit attendre le montage client (document indisponible en SSR).
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) return null;

  return createPortal(
    <div
      className="fixed inset-0 z-[100] flex flex-col items-center justify-center"
      style={{
        background: 'radial-gradient(80% 80% at 50% 40%, #16204a 0%, #0a1130 60%, #060a1f 100%)',
        animation: 'us-fade .18s ease-out both',
      }}
      role="status"
      aria-live="polite"
    >
      <style>{`
        @keyframes us-fade { from { opacity: 0 } to { opacity: 1 } }
        @keyframes us-out {
          to { transform: translateX(-72px) scale(.45); opacity: 0; filter: blur(4px) }
        }
        @keyframes us-in {
          from { transform: translateX(72px) scale(.45); opacity: 0; filter: blur(4px) }
          60% { transform: translateX(-6px) scale(1.07); opacity: 1; filter: blur(0) }
          to { transform: translateX(0) scale(1); opacity: 1; filter: blur(0) }
        }
        @keyframes us-pulse {
          0%, 100% { transform: scale(1) }
          50% { transform: scale(1.06) }
        }
        @keyframes us-dot {
          0%, 80%, 100% { opacity: .25; transform: translateY(0) }
          40% { opacity: 1; transform: translateY(-3px) }
        }
      `}</style>

      <div className="relative h-28 w-28">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={fromSrc}
          alt=""
          className="absolute inset-0 h-full w-full object-contain"
          style={{ animation: 'us-out .4s ease-in .1s both' }}
        />
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={toSrc}
          alt=""
          className="absolute inset-0 h-full w-full object-contain drop-shadow-[0_0_24px_rgba(255,255,255,.25)]"
          style={{
            animation:
              'us-in .55s cubic-bezier(.2,.8,.3,1.2) .3s both, us-pulse 1.6s ease-in-out 1.2s infinite',
          }}
        />
      </div>

      <p className="mt-6 text-sm font-medium text-white/90">
        Bascule vers <span className="font-bold">{toName}</span>
        <span className="ml-1 inline-flex gap-0.5" aria-hidden>
          {[0, 1, 2].map((i) => (
            <span
              key={i}
              className="inline-block"
              style={{ animation: `us-dot 1.2s ease-in-out ${i * 0.15}s infinite` }}
            >
              ·
            </span>
          ))}
        </span>
      </p>
    </div>,
    document.body,
  );
}
