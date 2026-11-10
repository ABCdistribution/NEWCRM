import { redirect } from 'next/navigation';
import { getNotifications } from '@/lib/api';
import { espaceDe, lireSession, urlLogin } from '@/lib/roles';
import { construireMenu } from '@/lib/menu';
import { SideMenu } from '@/components/side-menu';
import { ServiceIndisponible } from '@/components/service-indisponible';

/**
 * Layout de toute l'application connectée.
 *  - Session absente ou expirée (401) → /login?from=<page demandée>.
 *  - API injoignable ou en erreur (5xx) → écran « service indisponible », SANS redirection : le cookie est
 *    peut-être encore valable, renvoyer vers /login ferait croire à une déconnexion.
 * Le thème (bleu / violet) suit le RÔLE, pas le groupe de routes : l'encadrement ouvre aussi
 * les écrans terrain et garde son thème violet.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const session = await lireSession();
  if (session.etat === 'absente') redirect(await urlLogin());
  if (session.etat === 'indisponible') return <ServiceIndisponible />;
  const { me } = session;

  const espace = espaceDe(me.role);
  // Cloche de notifications : tous les rôles. L'API ne renvoie que les notifications de l'utilisateur connecté
  // (par exemple les relances d'un directeur régional à un chef de secteur).
  const notifications = (await getNotifications()) ?? { nonLues: 0, items: [] };

  return (
    // Mobile : barre hamburger au-dessus du contenu ; ≥ md : sidebar + contenu côte à côte.
    <div data-espace={espace} className="min-h-screen md:flex">
      <SideMenu
        // Seuls les champs utilisés par le menu partent vers le navigateur (pas l'objet `me` entier).
        me={{ id: me.id, displayName: me.displayName, poste: me.poste, role: me.role }}
        espace={espace}
        sections={construireMenu(me.role, espace)}
        notifications={notifications}
      />
      <main className="min-w-0 flex-1">
        <div className="mx-auto max-w-[88rem] px-4 py-4 sm:px-6 sm:py-6">{children}</div>
      </main>
    </div>
  );
}
