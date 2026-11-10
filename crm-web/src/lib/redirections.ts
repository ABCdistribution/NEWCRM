/**
 * Redirections de compatibilité : anciennes adresses d'ABC Sales et d'ABC Pilot -> adresses de crm-web.
 *
 * Origine. crm-web fusionne les deux anciens fronts : ABC Sales (crm-promoteur, port 3000, pages à la
 * racine : /tournees, /planification, /clients...) et ABC Pilot (crm-helios, port 3001, pages sous le
 * préfixe /pilotage). Les anciennes adresses survivent dans les favoris, les historiques de navigation,
 * les e-mails et dans les liens que l'API a déjà enregistrés dans les notifications
 * (`/tournees`, `/pilotage/ma-tournee` ; l'affichage les réécrit aussi : cheminCompatible, dans chemin.ts, lit cette
 * même table, aucune règle n'y est dupliquée).
 *
 * Fonctionnement. Source de vérité UNIQUE, lue par `redirects()` dans next.config.ts. Ces redirections
 * passent AVANT le middleware et les pages : aucune source ne doit donc correspondre à une vraie page de
 * crm-web (les sources commencent par /pilotage, ou sont /tournees et /planification, qui n'existent plus).
 * Le premier motif qui correspond l'emporte : du plus spécifique au plus général, règle générale en dernier.
 * Syntaxe Next (`:id`, `:path*`). La chaîne de requête de l'ancienne adresse est conservée par Next
 * (?semaine=..., ?search=...) ; celle de la destination l'emporte si une clé est en double.
 *
 * Statut. `permanent: true` (308) : les anciennes adresses disparaissent pour de bon, navigateurs et robots
 * doivent retenir la nouvelle. Un 308 est mis en cache durablement par les navigateurs et ne se corrige plus
 * chez eux : tant que cette table doit encore évoluer, PERMANENT reste à false (307). Elle n'est pas stabilisée :
 * la cible de /pilotage/clients vient d'être corrigée, MARKETING et ADV n'ont pas d'espace défini et la migration
 * est en cours. Passer PERMANENT à true seulement à la mise en production, une fois la table figée.
 *
 * Hôtes. Ces règles ne s'exécutent que pour les requêtes qui ARRIVENT sur crm-web (port 3001, repris d'ABC Pilot). Les anciens
 * favoris d'ABC Pilot (port 3001) arrivent donc déjà sur crm-web ; ceux d'ABC Sales (3000 en développement, 3002 en production)
 * ne servent qu'une fois le déploiement aligné, c'est-à-dire quand ces anciennes adresses d'hôte ou de port sont dirigées
 * vers crm-web.
 * À reporter dans la fiche de déploiement.
 *
 * Adresses INCHANGÉES, donc sans redirection (une source ici masquerait la vraie page) :
 *  - ABC Sales : /, /agenda, /clients, /clients/:id, /commandes, /commandes/:id, /news, /parametres,
 *    /produits, /promos, /qualite, /visites ;
 *  - ABC Sales et ABC Pilot : /login, /avatar/:id ; ABC Pilot seul : /pj/:id/:pjId ;
 *  - l'ancienne racine « / » d'ABC Pilot renvoyait vers /pilotage : « / » est désormais l'accueil.
 * Volontairement NON reprise : l'ancien rewrite /api/:path* vers l'API (le navigateur n'appelle jamais l'API,
 * uniquement serverFetch et les Server Actions).
 *
 * Ce module ne contient que des données (aucun import, aucun alias « @/ ») : next.config.ts le charge avant
 * la compilation de l'application. `next dev` ne surveille que next.config.ts : après une modification de ce
 * fichier, redémarrer le serveur (ou toucher next.config.ts).
 */

/** true = 308 (permanent), false = 307 (temporaire) : voir « Statut » ci-dessus. */
const PERMANENT = false;

export type Redirection = {
  /** Ancienne adresse (syntaxe Next : `:id`, `:path*`). */
  source: string;
  /** Nouvelle adresse dans crm-web ; peut porter une chaîne de requête. */
  destination: string;
  /** true = 308, false = 307. */
  permanent: boolean;
};

export const REDIRECTIONS: Redirection[] = [
  // --- Ancien ABC Pilot (crm-helios), préfixe /pilotage ---
  // Accueil.
  { source: '/pilotage', destination: '/', permanent: PERMANENT },
  // Suivi des clients (carte + tableau) : devenu la vue « Suivi du secteur » de /clients (encadrement).
  // Il n'y avait pas de /pilotage/magasins/:id : la fiche d'un client était /pilotage/clients/:id.
  { source: '/pilotage/magasins', destination: '/clients', permanent: PERMANENT },
  { source: '/pilotage/magasins/:id/visite', destination: '/clients/:id/visite', permanent: PERMANENT },
  // Liste des clients : l'ancienne /pilotage/clients (?search=&page=, bandeau KPI) était le PORTEFEUILLE, pas le suivi.
  // Pour l'encadrement, /clients ouvre par défaut la vue « suivi » : on cible donc la vue « portefeuille »
  // (?vue=portefeuille), qui relit ?search= et ?page= sur le même jeu de données qu'avant. Les paramètres de
  // l'ancienne adresse sont conservés par Next ; ceux de la destination l'emportent en cas de doublon.
  { source: '/pilotage/clients', destination: '/clients?vue=portefeuille', permanent: PERMANENT },
  // Fiche client : même adresse sans le préfixe (listée pour mémoire, la règle générale ferait pareil).
  { source: '/pilotage/clients/:id', destination: '/clients/:id', permanent: PERMANENT },
  // « Mon planning d'activité » de l'encadrement : fusionné avec /tournees dans /planning (une URL, deux vues selon le rôle).
  { source: '/pilotage/ma-tournee', destination: '/planning', permanent: PERMANENT },
  // Planning de l'équipe : fusionné avec /planification (ABC Sales) dans /planning-equipe.
  { source: '/pilotage/planning-equipe', destination: '/planning-equipe', permanent: PERMANENT },
  // L'ancienne page renvoyait vers l'onglet Configuration de l'administration ; /parametres fait de même pour
  // ADMIN (et refuse les autres rôles).
  { source: '/pilotage/parametres', destination: '/parametres', permanent: PERMANENT },
  // L'ancienne page Utilisateurs est devenue un onglet de l'administration (ADMIN).
  { source: '/pilotage/users', destination: '/admin?onglet=utilisateurs', permanent: PERMANENT },

  // --- Ancien ABC Sales (crm-promoteur), pages à la racine ---
  // Planification des visites (encadrement) : fusionnée avec le planning de l'équipe d'ABC Pilot.
  { source: '/planification', destination: '/planning-equipe', permanent: PERMANENT },
  // « Mon planning » du promoteur (lecture seule) : devenu la vue terrain de /planning.
  { source: '/tournees', destination: '/planning', permanent: PERMANENT },

  // --- Règle générale, EN DERNIER : toute autre adresse /pilotage/... perd son préfixe ---
  // Couvre /pilotage/admin, /alertes, /commandes(/:id), /mon-equipe(/:id, /:id/planning, /promoteur/:id), /news,
  // /produits, /promos, /prospects(/:id), /qualite et /rapports, qui existent à l'identique dans crm-web.
  { source: '/pilotage/:path*', destination: '/:path*', permanent: PERMANENT },
];
