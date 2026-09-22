import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Selios — CRM Commercial ABC',
  description: 'Portail terrain des commerciaux ABC Distribution',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    // Thème : contenu clair (fond blanc) ; seule la sidebar est en navy
    // (classe .dark posée localement sur l'<aside> dans side-menu).
    <html lang="fr" suppressHydrationWarning>
      {/* suppressHydrationWarning : neutralise les attributs injectés par des extensions
          navigateur (gestionnaires de mots de passe, Grammarly…) sur html/body, qui
          déclenchent un faux avertissement d'hydratation. N'affecte pas le contenu de l'app. */}
      <body suppressHydrationWarning>{children}</body>
    </html>
  );
}
