import {
  Home,
  Newspaper,
  Store,
  ShoppingCart,
  Footprints,
  Package,
  BadgePercent,
  ShieldAlert,
  CalendarDays,
  CalendarCog,
  Settings,
  Sprout,
  UsersRound,
  ClipboardCheck,
  AlertTriangle,
  ShieldCheck,
  CalendarRange,
  type LucideIcon,
} from 'lucide-react';
import { ENCADREMENT, ROLES_COMMANDES_VISITES, TOUS_ROLES, type Espace, type Role } from './roles';

export type Route = {
  href: string;
  label: string;
  icon: LucideIcon;
  /** Rôles autorisés (la page applique la même règle via requireRole). */
  roles: readonly Role[];
  /** 'commun' = écran présent dans les deux espaces ; sinon espace propriétaire. */
  espace: Espace | 'commun';
  /** Dans le menu latéral ? (false = page de détail ou page d'appoint). */
  menu?: boolean;
};

/**
 * Table unique des routes de crm-web (sans préfixe d'URL). Alimentera le menu et les gardes.
 * Pages de détail à garder (hors menu) :
 *  - /clients/[id], /commandes/[id], /prospects/[id]
 *  - /mon-equipe/[id] (DIRECTEUR_REGIONAL, ADMIN) et /mon-equipe/promoteur/[id] (ADMIN, DR, CS)
 * Décision : l'encadrement garde l'accès aux écrans terrain.
 */
export const ROUTES: readonly Route[] = [
  { href: '/', label: 'Accueil', icon: Home, roles: TOUS_ROLES, espace: 'commun', menu: true },
  { href: '/news', label: 'Les News', icon: Newspaper, roles: TOUS_ROLES, espace: 'commun', menu: true },

  // Écrans communs (les données sont filtrées par périmètre côté API)
  { href: '/clients', label: 'Les clients', icon: Store, roles: TOUS_ROLES, espace: 'commun', menu: true },
  // Commandes et visites : pas d'accès pour le marketing.
  { href: '/commandes', label: 'Les commandes', icon: ShoppingCart, roles: ROLES_COMMANDES_VISITES, espace: 'commun', menu: true },
  { href: '/visites', label: 'Les visites', icon: Footprints, roles: ROLES_COMMANDES_VISITES, espace: 'commun', menu: true },
  { href: '/produits', label: 'Les produits', icon: Package, roles: TOUS_ROLES, espace: 'commun', menu: true },
  { href: '/promos', label: 'Les promos / PEM', icon: BadgePercent, roles: TOUS_ROLES, espace: 'commun', menu: true },
  { href: '/qualite', label: 'Qualité & rappels', icon: ShieldAlert, roles: TOUS_ROLES, espace: 'commun', menu: true },
  // Fusion de /tournees (promoteurs, COMMERCIAL) et /ma-tournee (planning d'activité de l'encadrement)
  { href: '/planning', label: 'Mon planning', icon: CalendarDays, roles: [...ENCADREMENT, 'COMMERCIAL'], espace: 'commun', menu: true },
  // Fusion de /planification (ABC Sales) et /planning-equipe (ABC Pilot) : encadrement
  { href: '/planning-equipe', label: "Planning de l'équipe", icon: CalendarCog, roles: ENCADREMENT, espace: 'commun', menu: true },
  // Redirige vers /admin?onglet=configuration : ADMIN seulement (la page applique requireRole(['ADMIN']))
  { href: '/parametres', label: 'Paramètres', icon: Settings, roles: ['ADMIN'], espace: 'commun' },

  // Espace Direction commerciale uniquement
  { href: '/prospects', label: 'Prospection', icon: Sprout, roles: ENCADREMENT, espace: 'direction', menu: true },
  // Exclut DIRECTION (sous-page /mon-equipe/[id] : DIRECTEUR_REGIONAL et ADMIN seulement)
  { href: '/mon-equipe', label: 'Mon équipe', icon: UsersRound, roles: ['ADMIN', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'], espace: 'direction', menu: true },
  // Exclut CHEF_SECTEUR
  { href: '/rapports', label: "Rapports d'activité", icon: ClipboardCheck, roles: ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'], espace: 'direction', menu: true },
  { href: '/alertes', label: 'Alertes', icon: AlertTriangle, roles: ENCADREMENT, espace: 'direction', menu: true },
  { href: '/admin', label: 'Administration', icon: ShieldCheck, roles: ['ADMIN'], espace: 'direction', menu: true },

  // Espace Promoteurs uniquement (page « bientôt » pour l'instant)
  { href: '/agenda', label: 'Agenda', icon: CalendarRange, roles: ['COMMERCIAL', 'ADV'], espace: 'promoteurs' },
];

/** Routes visibles dans le menu pour un rôle et un espace. */
export function routesMenu(role: Role, espace: Espace): Route[] {
  return ROUTES.filter(
    (r) => r.menu && r.roles.includes(role) && (r.espace === 'commun' || r.espace === espace),
  );
}
