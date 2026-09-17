'use client';

import { useEffect, useState } from 'react';

// Selios tourne sur le même serveur ; le port est fixé au build (3002 par défaut).
const SELIOS_PORT = process.env.NEXT_PUBLIC_SELIOS_PORT ?? '3002';

/** Lien vers une page de l'univers terrain (Selios) — l'hôte est repris à l'exécution. */
export function SeliosLink({
  path,
  className,
  children,
}: {
  path: string; // ex. "/planification?promoteur=…"
  className?: string;
  children: React.ReactNode;
}) {
  const [href, setHref] = useState<string>();
  useEffect(() => {
    setHref(`${window.location.protocol}//${window.location.hostname}:${SELIOS_PORT}${path}`);
  }, [path]);
  return (
    <a href={href} className={className}>
      {children}
    </a>
  );
}
