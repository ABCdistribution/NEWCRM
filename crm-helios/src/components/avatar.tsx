'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * Avatar : initiales par défaut, la photo n'est révélée que si elle charge.
 * Une image absente/404 reste invisible (opacity-0) → jamais d'icône « image cassée ».
 * ⚠️ Une image en cache peut finir de charger AVANT l'hydratation React (l'événement
 * `onLoad` est alors raté) : l'effet vérifie `img.complete` pour couvrir ce cas.
 */
export function Avatar({
  src,
  initials,
  size = 40,
  className = '',
}: {
  src?: string;
  initials: string;
  size?: number;
  className?: string;
}) {
  const [loaded, setLoaded] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);
  const dim = { width: size, height: size };

  useEffect(() => {
    const img = imgRef.current;
    if (img && img.complete && img.naturalWidth > 0) setLoaded(true);
  }, []);

  return (
    <span className={`relative inline-flex shrink-0 ${className}`} style={dim}>
      <span
        className={`absolute inset-0 flex items-center justify-center rounded-full bg-neutral-200 text-xs font-semibold text-neutral-700 transition-opacity dark:bg-navy-800 dark:text-neutral-200 ${
          loaded ? 'opacity-0' : 'opacity-100'
        }`}
      >
        {initials || '?'}
      </span>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          ref={imgRef}
          src={src}
          alt=""
          style={dim}
          onLoad={() => setLoaded(true)}
          className={`absolute inset-0 rounded-full object-cover transition-opacity ${
            loaded ? 'opacity-100' : 'opacity-0'
          }`}
        />
      ) : null}
    </span>
  );
}
