import type { Metadata } from 'next';
import '@fontsource-variable/inter';
import './globals.css';

export const metadata: Metadata = {
  title: 'SalesPilot ABC',
  description: 'Plateforme commerciale ABC Distribution',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    // Pas de data-espace ici : il est posé par les layouts des groupes de routes
    // (promoteurs) et (direction). La classe .dark est posée localement (menu, cartes).
    <html lang="fr" suppressHydrationWarning>
      {/* suppressHydrationWarning : neutralise les attributs injectés par des extensions
          navigateur (gestionnaires de mots de passe, Grammarly…) sur html/body. */}
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
