import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/auth/session.dart';
import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/ui/ui.dart';
import 'logic/attente_crm.dart';
import 'logic/attente_crm_corps.dart';
import 'state/attente_provider.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'state/sous_onglet_commandes.dart';

/// Retour après une commande mise en attente ou validée sans visite : le promoteur arrive sur l'onglet
/// « Commandes » (`S.pile = []; S.sOnglet = 2`), l'encadrement revient à l'écran racine.
void _retourListe(BuildContext context, Role role) {
  if (role == Role.promoteur) {
    AppRoutes.allerOnglet(context, OngletApp.commandes);
  } else {
    AppRoutes.retourRacine(context);
  }
}

/// Une écriture vers le CRM est en cours : un second appui n'en lance pas une autre.
bool _envoiEnCours = false;

/// Fait l'appel `appel` en gardant [_envoiEnCours] ; renvoie le message à afficher si l'appel échoue, nul sinon.
Future<String?> _ecrire(Future<void> Function() appel) async {
  if (_envoiEnCours) return 'Une opération est déjà en cours.';
  _envoiEnCours = true;
  try {
    await appel();
    return null;
  } on ErreurApi catch (e) {
    return e.message;
  } catch (_) {
    return const ErreurApi(TypeErreurApi.inattendue).message;
  } finally {
    _envoiEnCours = false;
  }
}

double? _prixArticle(String id) => produitParId(id)?.prix;

/// Enregistre la commande en cours dans le CRM : la crée si elle n'y est pas encore, sinon n'envoie que ce qui a
/// changé. La commande en cours garde ensuite l'état du CRM comme référence.
Future<CommandeAttenteCrm> _enregistrerAuCrm(ProviderContainer c) async {
  final cmd = c.read(commandeEnCoursProvider);
  if (cmd == null) throw const ErreurApi(TypeErreurApi.inattendue);
  final synchro = c.read(commandesAttenteSynchroProvider.notifier);
  final crm = cmd.crm;
  final CommandeAttenteCrm resultat;
  if (crm == null) {
    // L'identifiant est fixé avant l'envoi : après une coupure, le nouvel essai ne crée pas de doublon.
    final idApk = cmd.idApk ?? genererIdApk();
    c.read(commandeEnCoursProvider.notifier).fixerIdApk(idApk);
    resultat = await synchro.creer(
      corpsCreation(
        cmd,
        idApk: idApk,
        maintenant: DemoTemps.maintenant(),
        prixDe: _prixArticle,
      ),
    );
  } else {
    final corps = corpsModification(cmd, crm, _prixArticle);
    resultat = corps.isEmpty ? crm : await synchro.modifier(crm.id, corps);
  }
  if (c.read(commandeEnCoursProvider) != null) {
    c.read(commandeEnCoursProvider.notifier).lierCrm(resultat);
  }
  return resultat;
}

/// « ⏸ Mettre en attente » (`cmd-attente`) : la commande est mise de côté, non envoyée.
///
/// Connecté en promoteur, elle est enregistrée dans le CRM (création, ou modification si elle en vient) : sans
/// réseau, un message l'indique et la commande reste dans le panier.
Future<void> mettreEnAttente(BuildContext context, WidgetRef ref) async {
  final cmd = ref.read(commandeEnCoursProvider);
  // Commande déjà traitée (second appui pendant la sortie de l'écran) : rien à faire.
  if (cmd == null) return;
  if (cmd.lignes.isEmpty) {
    AppToast.show(context, 'Rien à mettre en attente : le panier est vide.');
    return;
  }
  final role = ref.read(roleActifProvider);
  if (ref.read(sessionProvider) != null) {
    if (!ref.read(attenteCrmActiveProvider)) {
      AppToast.show(
        context,
        'Seul un promoteur peut mettre une commande en attente.',
      );
      return;
    }
    final c = ProviderScope.containerOf(context);
    final dejaAuCrm = cmd.crm != null;
    final erreur = await _ecrire(() async => _enregistrerAuCrm(c));
    if (!context.mounted) return;
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    c.read(commandeEnCoursProvider.notifier).terminer();
    c
        .read(sousOngletCommandesProvider.notifier)
        .choisir(SousOngletCommandes.attente);
    AppToast.show(
      context,
      dejaAuCrm
          ? 'Commande enregistrée en attente.'
          : 'Commande mise en attente.',
    );
    _retourListe(context, role);
    return;
  }
  ref
      .read(attenteProvider.notifier)
      .mettreDeCote(
        CommandeEnAttente(
          magasinId: cmd.magasinId ?? '',
          lignes: List.of(cmd.lignes),
          pas: cmd.pas,
          dateMin: cmd.dateMin,
          motifPas: cmd.motifPas,
          motifAutre: cmd.motifAutre,
          note: cmd.note,
          date: DemoTemps.maintenantCourt,
        ),
        rang: cmd.deAttente,
      );
  ref.read(commandeEnCoursProvider.notifier).terminer();
  AppToast.show(
    context,
    'Commande mise en attente. Retrouvez-la dans Commandes pour la reprendre.',
  );
  _retourListe(context, role);
}

/// « ✓ Valider » (`cmd-valider`) : contrôles, puis la commande est ajoutée au suivi de livraison.
///
/// Une commande reprise du CRM y est d'abord enregistrée si elle a été modifiée, puis validée : elle quitte la liste
/// des commandes en attente.
Future<void> validerCommande(BuildContext context, WidgetRef ref) async {
  final cmd = ref.read(commandeEnCoursProvider);
  // Commande déjà traitée (second appui pendant la sortie de l'écran) : rien à faire.
  if (cmd == null) return;
  if (cmd.lignes.isEmpty) {
    AppToast.show(context, 'Le panier est vide : ajoutez au moins un produit.');
    return;
  }
  for (final l in cmd.lignes) {
    final p = produitParId(l.produitId);
    if (p != null && l.qty > (p.qte ?? 0)) {
      AppToast.show(
        context,
        'Stock insuffisant pour « ${p.nom} » : choisissez un remplacement ou baissez la quantité.',
      );
      return;
    }
  }
  if (cmd.pas &&
      (cmd.dateMin.isEmpty ||
          cmd.motifPas.isEmpty ||
          (cmd.motifPas == 'Autre' && cmd.motifAutre.trim().isEmpty))) {
    AppToast.show(
      context,
      'Précisez le motif et la date de la consigne « ne pas livrer avant ».',
    );
    AppRoutes.nePasLivrerAvant(context);
    return;
  }

  final c = ProviderScope.containerOf(context);
  final role = c.read(roleActifProvider);
  final auCrm = cmd.crm != null && c.read(attenteCrmActiveProvider);
  if (auCrm) {
    final erreur = await _ecrire(() async {
      final crm = await _enregistrerAuCrm(c);
      await c.read(commandesAttenteSynchroProvider.notifier).valider(crm.id);
    });
    if (!context.mounted) return;
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
  }
  // La commande a pu être terminée pendant l'attente du serveur.
  final courante = c.read(commandeEnCoursProvider) ?? cmd;

  final store = c.read(crmProvider.notifier);
  final num = store.prochainIdCommande;
  final total = eurD(courante.total);
  store.ajouterCommande(
    Commande(
      src: 'Appli',
      par: role.profil.nom,
      id: num,
      magasinId: courante.magasinId ?? '',
      date: DemoTemps.jourCourt,
      ht: total,
      lignes: courante.lignes.length,
      statut: StatutLivraison.pasLivree,
      eta: courante.pas
          ? 'à partir du ${dateFr(courante.dateMin)}'
          : DemoTemps.livraisonPrevue,
      pasAvant: courante.pas ? courante.dateMin : null,
      motifPas: courante.pas
          ? motifFinal(courante.motifPas, courante.motifAutre)
          : null,
      note: courante.note,
      colis: math.max(1, (courante.nbArticles / 12).ceil()),
      evenements: [
        EvenementTransport('Commande reçue', DemoTemps.maintenantCourt),
      ],
    ),
  );
  if (courante.deAttente != null) {
    c.read(attenteProvider.notifier).retirer(courante.deAttente!);
  }
  final visiteId = courante.depuisVisite;
  final visiteExiste =
      visiteId != null &&
      c.read(crmProvider).visites.any((v) => v.id == visiteId);
  if (visiteExiste) {
    store.majVisite(
      visiteId,
      (v) => v.copyWith(
        cmd: CommandeLiee(
          id: num.replaceFirst('CDE-', ''),
          ht: total,
          liv: DemoTemps.livraisonPrevueNumerique,
        ),
      ),
    );
  }
  c.read(commandeEnCoursProvider.notifier).terminer();
  AppToast.show(
    context,
    'Commande $num ${auCrm ? 'validée' : 'enregistrée'}'
    '${courante.pas ? ' · livraison à partir du ${dateFr(courante.dateMin)}' : ''}.'
    '${auCrm ? '' : ' Envoi dès que le réseau le permet.'}',
  );
  if (visiteExiste) {
    // La pile de la maquette ne garde que la visite : on revient sur son écran.
    Navigator.of(
      context,
    ).popUntil((r) => r.settings.name == 'visite' || r.isFirst);
  } else {
    _retourListe(context, role);
  }
}

/// Envoie la commande en cours par mail au client pour validation. Elle est d'abord enregistrée dans le CRM (créée ou
/// mise à jour : le mail porte son contenu actuel) et reste en attente. Renvoie le message d'erreur, nul si le mail est
/// parti.
Future<String?> envoyerCommandeParMail(ProviderContainer c, String email) =>
    _ecrire(() async {
      final crm = await _enregistrerAuCrm(c);
      final maj = await c
          .read(commandesAttenteSynchroProvider.notifier)
          .envoyerMail(crm.id, email.trim());
      if (c.read(commandeEnCoursProvider) != null) {
        c.read(commandeEnCoursProvider.notifier).lierCrm(maj);
      }
    });

/// Supprime une commande en attente du CRM. Renvoie le message d'erreur, nul si elle est supprimée.
Future<String?> supprimerCommandeEnAttente(ProviderContainer c, String id) =>
    _ecrire(
      () => c.read(commandesAttenteSynchroProvider.notifier).supprimer(id),
    );
