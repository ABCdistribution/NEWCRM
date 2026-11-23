import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accueil/alertes_sheet.dart';
import '../../features/catalogue/fiche_produit_sheet.dart';
import '../../features/catalogue/filtres_catalogue_sheet.dart';
import '../../features/catalogue/news_detail_sheet.dart';
import '../../features/clients/fiche_magasin_screen.dart';
import '../../features/clients/filtres_clients_sheet.dart';
import '../../features/clients/note_client_dialog.dart';
import '../../features/commandes/detail_livraison_sheet.dart';
import '../../features/commandes/filtres_commandes_sheet.dart';
import '../../features/commandes/filtres_prise_commande_sheet.dart';
import '../../features/commandes/ne_pas_livrer_avant_sheet.dart';
import '../../features/commandes/panier_screen.dart';
import '../../features/commandes/prise_commande_screen.dart';
import '../../features/commandes/produits_remplacement_sheet.dart';
import '../../features/commandes/scan_produit_sheet.dart';
import '../../features/equipe/chef_secteur_screen.dart';
import '../../features/equipe/choix_client_secteur_sheet.dart';
import '../../features/equipe/filtres_equipe_sheet.dart';
import '../../features/equipe/filtres_secteur_sheet.dart';
import '../../features/equipe/filtres_semaines_sheet.dart';
import '../../features/equipe/promoteur_screen.dart';
import '../../features/equipe/semaine_cs_screen.dart';
import '../../features/planning/formulaire_rdv_sheet.dart';
import '../../features/planning/rapport_detail_sheet.dart';
import '../../features/prospects/changer_etape_sheet.dart';
import '../../features/prospects/fiche_prospect_screen.dart';
import '../../features/prospects/filtres_prospects_sheet.dart';
import '../../features/prospects/note_prospect_dialog.dart';
import '../../features/prospects/nouveau_prospect_screen.dart';
import '../../features/prospects/passer_en_client_dialog.dart';
import '../../features/shell/feuille_profil.dart';
import '../../features/visites/compte_rendu_screen.dart';
import '../../features/visites/filtres_visites_sheet.dart';
import '../../features/visites/kilometrage_dialog.dart';
import '../../features/visites/kit_detail_sheet.dart';
import '../../features/visites/kits_sheet.dart';
import '../../features/visites/valider_visite_dialog.dart';
import '../../features/visites/visite_screen.dart';
import '../models/models.dart';
import '../state/state.dart';
import 'onglets.dart';

/// Toutes les navigations entre écrans, en un seul endroit : une fonction statique par écran empilé
/// ou feuille partagée, avec des arguments typés (ids).
///
/// Les lots s'appellent entre eux **uniquement** par `AppRoutes` : aucun lot n'importe l'écran d'un autre lot.
/// Les écrans empilés sont de vraies routes (`Navigator.push`) : ils recouvrent la barre de navigation,
/// comme dans la maquette (la « pile »). Retour : `Navigator.of(context).pop()` ou `BoutonRetour`.
class AppRoutes {
  const AppRoutes._();

  static Future<T?> _pousser<T>(
    BuildContext context,
    String nom,
    Widget ecran,
  ) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        settings: RouteSettings(name: nom),
        builder: (_) => ecran,
      ),
    );
  }

  static ProviderContainer _conteneur(BuildContext context) =>
      ProviderScope.containerOf(context);

  // ---- Onglets ------------------------------------------------------------

  /// Va sur un onglet : vide la pile d'écrans empilés, ferme le menu « + » (maquette : `onglet`, `songlet`).
  static void allerOnglet(BuildContext context, OngletApp onglet) {
    final c = _conteneur(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    c.read(ongletProvider.notifier).aller(onglet);
    c.read(menuPlusOuvertProvider.notifier).fermer();
  }

  /// Revient au premier écran (l'onglet courant) en fermant tous les écrans empilés.
  static void retourRacine(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  /// Revient à l'écran précédent.
  static void retour(BuildContext context) => Navigator.of(context).maybePop();

  // ---- Clients ------------------------------------------------------------

  /// Fiche d'un client (`ecranPile` : `magasin`). `surOnglet` : pose d'abord cet onglet sous la fiche.
  static Future<void> ficheMagasin(
    BuildContext context,
    String magasinId, {
    OngletApp? surOnglet,
  }) {
    if (surOnglet != null) allerOnglet(context, surOnglet);
    return _pousser<void>(
      context,
      'magasin',
      FicheMagasinScreen(magasinId: magasinId),
    );
  }

  /// Feuille de filtres de la liste des clients (`mfiltres`).
  static Future<void> filtresClients(BuildContext context) =>
      ouvrirFiltresClients(context);

  /// Dialogue « Nouvelle note » sur un client (`note`, depuis une fiche client).
  static Future<void> noteClient(BuildContext context, String magasinId) =>
      ouvrirNoteClient(context, magasinId);

  // ---- Prospects ----------------------------------------------------------

  /// Fiche d'un prospect (`prospect`). `surOnglet` : pose d'abord cet onglet sous la fiche.
  static Future<void> ficheProspect(
    BuildContext context,
    String prospectId, {
    OngletApp? surOnglet,
  }) {
    if (surOnglet != null) allerOnglet(context, surOnglet);
    return _pousser<void>(
      context,
      'prospect',
      FicheProspectScreen(prospectId: prospectId),
    );
  }

  /// Formulaire « Nouveau prospect » (`nouveau-prospect`).
  static Future<void> nouveauProspect(BuildContext context) => _pousser<void>(
    context,
    'nouveau-prospect',
    const NouveauProspectScreen(),
  );

  /// Feuille « Changer d'étape » d'un prospect (`feuille-etape`).
  static Future<void> changerEtapeProspect(
    BuildContext context,
    String prospectId,
  ) => ouvrirChangerEtape(context, prospectId);

  /// Confirmation « Passer en client ? » (`confirm`, action `en-client`).
  static Future<void> passerEnClient(BuildContext context, String prospectId) =>
      ouvrirPasserEnClient(context, prospectId);

  /// Dialogue « Nouvelle note » sur un prospect (`note`, depuis une fiche prospect).
  static Future<void> noteProspect(BuildContext context, String prospectId) =>
      ouvrirNoteProspect(context, prospectId);

  /// Feuille de filtres des prospects du directeur (`pv-filtres`).
  static Future<void> filtresProspects(BuildContext context) =>
      ouvrirFiltresProspects(context);

  // ---- Visites ------------------------------------------------------------

  /// Écran d'une visite (`visite`) : étapes si c'est un brouillon, compte rendu sinon.
  static Future<void> visite(BuildContext context, String visiteId) =>
      _pousser<void>(context, 'visite', VisiteScreen(visiteId: visiteId));

  /// Démarre (ou reprend) une visite chez un client : crée le brouillon dans le store puis ouvre l'écran
  /// (maquette : `startVisite`).
  static Future<void> demarrerVisite(BuildContext context, String magasinId) {
    final id = _conteneur(
      context,
    ).read(crmProvider.notifier).demarrerVisite(magasinId);
    return visite(context, id);
  }

  /// Démarre (ou reprend) la visite PEM qui répond à une proposition du CRM : crée le brouillon de type PEM lié à la
  /// proposition, puis ouvre l'écran de la visite.
  static Future<void> demarrerVisitePem(
    BuildContext context,
    String magasinId,
    String propositionPemId,
  ) {
    final id = _conteneur(
      context,
    ).read(crmProvider.notifier).demarrerVisitePem(magasinId, propositionPemId);
    return visite(context, id);
  }

  /// Compte rendu d'une visite terminée ou d'un autre promoteur (`cr`), en lecture seule.
  static Future<void> compteRendu(BuildContext context, String visiteId) =>
      _pousser<void>(context, 'cr', CompteRenduScreen(visiteId: visiteId));

  /// Feuille de filtres de la liste des visites (`vfiltres`).
  static Future<void> filtresVisites(BuildContext context) =>
      ouvrirFiltresVisites(context);

  /// Dialogue de kilométrage de départ ou d'arrivée (`km`).
  static Future<void> kilometrage(
    BuildContext context,
    PhaseKilometrage phase,
  ) => ouvrirKilometrage(context, phase);

  /// Feuille « Kits du rayon » d'une visite (`kits`).
  static Future<void> kitsDuRayon(BuildContext context, String visiteId) =>
      ouvrirKitsDuRayon(context, visiteId);

  /// Feuille de composition d'un kit (`kit-detail`) ; `codeKit` : « COSMIA-01 », « KIT91265 », « 900024 »…
  static Future<void> detailKit(BuildContext context, String codeKit) =>
      ouvrirDetailKit(context, codeKit);

  /// Dialogue « Valider la visite ? » ou « Visite incomplète » (`svalider`).
  static Future<void> validerVisite(BuildContext context, String visiteId) =>
      ouvrirValiderVisite(context, visiteId);

  // ---- Commandes ----------------------------------------------------------

  /// Prise de commande (`cmd`). Sans `magasinId`, l'écran commence par le choix du client (« Étape 1 sur 2 »).
  /// `visiteId` : commande liée à une visite en cours.
  static Future<void> priseCommande(
    BuildContext context, {
    String? magasinId,
    String? visiteId,
  }) => _pousser<void>(
    context,
    'cmd',
    PriseCommandeScreen(magasinId: magasinId, visiteId: visiteId),
  );

  /// Panier de la commande en cours (`cmd-panier`).
  static Future<void> panierCommande(BuildContext context) =>
      _pousser<void>(context, 'cmd-panier', const PanierScreen());

  /// Feuille « suivi du transport » d'une commande (`slivraison`).
  static Future<void> detailLivraison(
    BuildContext context,
    String commandeId,
  ) => ouvrirDetailLivraison(context, commandeId);

  /// Feuille de filtres de la liste des commandes (`cfiltres`).
  static Future<void> filtresCommandes(BuildContext context) =>
      ouvrirFiltresCommandes(context);

  /// Feuille « Ne pas livrer avant… » de la commande en cours (`cmd-pas`).
  static Future<void> nePasLivrerAvant(BuildContext context) =>
      ouvrirNePasLivrerAvant(context);

  /// Feuille de scan simulé d'un code-barres (`cmd-scan`).
  static Future<void> scannerProduit(BuildContext context) =>
      ouvrirScanProduit(context);

  /// Feuille de filtres de la prise de commande (`cmd-filtres`).
  static Future<void> filtresPriseCommande(BuildContext context) =>
      ouvrirFiltresPriseCommande(context);

  /// Feuille « Produits de remplacement » d'un produit en rupture ou en stock insuffisant (`cmd-remp`).
  static Future<void> produitsRemplacement(
    BuildContext context,
    String produitId,
  ) => ouvrirProduitsRemplacement(context, produitId);

  // ---- Équipe -------------------------------------------------------------

  /// Page d'un chef de secteur vue par son directeur (`equipe-cs`) ; `csId` : « n », « k » ou « s ».
  static Future<void> pageChefSecteur(BuildContext context, String csId) =>
      _pousser<void>(context, 'equipe-cs', ChefSecteurScreen(csId: csId));

  /// Page d'un promoteur vue par son encadrement (`promo-page`) ; `csId` = son chef de secteur.
  static Future<void> pagePromoteur(
    BuildContext context, {
    required String csId,
    required String nom,
  }) => _pousser<void>(
    context,
    'promo-page',
    PromoteurScreen(csId: csId, nom: nom),
  );

  /// Une semaine du rapport d'un chef de secteur (`cs-sem`) : rapport et prévision.
  static Future<void> semaineChefSecteur(
    BuildContext context, {
    required String csId,
    required int numSemaine,
  }) => _pousser<void>(
    context,
    'cs-sem',
    SemaineCsScreen(csId: csId, numSemaine: numSemaine),
  );

  /// Feuille de filtres des visites ou commandes du secteur (`sec-filtres`).
  static Future<void> filtresSecteur(
    BuildContext context,
    GenreSecteur genre,
  ) => ouvrirFiltresSecteur(context, genre);

  /// Feuille « Choisir un client » des filtres du secteur (`sec-client`).
  static Future<void> choixClientSecteur(
    BuildContext context,
    GenreSecteur genre,
  ) => ouvrirChoixClientSecteur(context, genre);

  /// Feuille de filtres de l'onglet Équipe du directeur (`eq-filtres`).
  static Future<void> filtresEquipe(BuildContext context) =>
      ouvrirFiltresEquipe(context);

  /// Feuille « Filtrer les semaines » d'un chef de secteur (`cs-filtres`) ; `csId` : « n », « k » ou « s ».
  static Future<void> filtresSemainesChefSecteur(
    BuildContext context,
    String csId,
  ) => ouvrirFiltresSemaines(context, csId);

  // ---- Planning -----------------------------------------------------------

  /// Feuille de saisie d'une ligne de planning (`formulaire`).
  ///
  /// - `cible`/`ref` : pré-remplissage (ex. depuis une fiche client) ; `depuisFiche` masque le choix de la cible.
  /// - `visite` : indicateur « visite simple » de la nouvelle ligne (vrai par défaut ; les boutons « Planifier » des
  ///   fiches client et prospect passent `visite: false`, comme `planifier` l.2033 de la maquette). Le type choisi dans
  ///   la feuille le remplace à l'enregistrement, sauf pour une ligne administrative.
  /// - `etapeId` : modification d'une ligne existante.
  /// - `planCible` : nom du promoteur dont l'encadrement compose le planning (`semaine` = décalage affiché).
  static Future<void> formulaireRdv(
    BuildContext context, {
    CiblePlanning? cible,
    String? ref,
    bool depuisFiche = false,
    bool visite = true,
    String? etapeId,
    String? planCible,
    int? semaine,
  }) => ouvrirFormulaireRdv(
    context,
    cible: cible,
    ref: ref,
    depuisFiche: depuisFiche,
    visite: visite,
    etapeId: etapeId,
    planCible: planCible,
    semaine: semaine,
  );

  /// Feuille de détail d'un rapport de semaine (`rapport-detail`) ; `numSemaine` : 45 (en cours) ou 44 à 41.
  static Future<void> detailRapport(BuildContext context, int numSemaine) =>
      ouvrirDetailRapport(context, numSemaine);

  // ---- Catalogue ----------------------------------------------------------

  /// Feuille de filtres du catalogue (`sfiltres`).
  static Future<void> filtresCatalogue(BuildContext context) =>
      ouvrirFiltresCatalogue(context);

  /// Feuille « fiche produit » (`sproduit`) ; `produitId` : « a1 », « kitKIT91265 », « pem20000 »…
  static Future<void> ficheProduit(BuildContext context, String produitId) =>
      ouvrirFicheProduit(context, produitId);

  /// Feuille de détail d'une news (`news`) ; `newsId` : « n1 » à « n4 ».
  static Future<void> detailNews(BuildContext context, String newsId) =>
      ouvrirDetailNews(context, newsId);

  // ---- Accueil et démo ----------------------------------------------------

  /// Feuille des alertes (la cloche de l'accueil) : `cloche`.
  static Future<void> alertes(BuildContext context) => ouvrirAlertes(context);

  /// Feuille « Changer de profil (démo) » : touche à l'avatar de l'accueil.
  static Future<void> changerProfil(BuildContext context) =>
      ouvrirChangerProfil(context);
}
