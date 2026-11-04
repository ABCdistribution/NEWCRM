'use client';

import { useEffect, useState } from 'react';

// ABC Sales tourne sur le même serveur ; le port est fixé au build (3002 par défaut) sauf si `port` est fourni.
const SELIOS_PORT = process.env.NEXT_PUBLIC_SELIOS_PORT ?? '3002';

/** Lien vers une page de l'univers terrain (ABC Sales) — l'hôte est repris à l'exécution. */
export function SeliosLink({
  path,
  port,
  className,
  children,
}: {
  path: string; // ex. "/planification?promoteur=…"
  /** Port d'ABC Sales fourni par le serveur (`SELIOS_PORT`) ; à défaut la valeur fixée au build. */
  port?: string;
  className?: string;
  children: React.ReactNode;
}) {
  const [href, setHref] = useState<string>();
  useEffect(() => {
    setHref(`${window.location.protocol}//${window.location.hostname}:${port ?? SELIOS_PORT}${path}`);
  }, [path, port]);
  return (
    <a href={href} className={className}>
      {children}
    </a>
  );
}
