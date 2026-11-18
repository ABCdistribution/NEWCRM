import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'state/attente_provider.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';

/// Retour après une commande mise en attente ou validée sans visite : le promoteur arrive sur l'onglet
/// « Commandes » (`S.pile = []; S.sOnglet = 2`), l'encadrement revient à l'écran racine.
void _retourListe(BuildContext context, Role role) {
  if (role == Role.promoteur) {
    AppRoutes.allerOnglet(context, OngletApp.commandes);
  } else {
    AppRoutes.retourRacine(context);
  }
}

/// « ⏸ Mettre en attente » (`cmd-attente`) : la commande est mise de côté, non envoyée.
void mettreEnAttente(BuildContext context, WidgetRef ref) {
  final cmd = ref.read(commandeEnCoursProvider);
  // Commande déjà traitée (second appui pendant la sortie de l'écran) : rien à faire.
  if (cmd == null) return;
  if (cmd.lignes.isEmpty) {
    AppToast.show(context, 'Rien à mettre en attente : le panier est vide.');
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
  final role = ref.read(roleActifProvider);
  AppToast.show(
    context,
    'Commande mise en attente. Retrouvez-la dans Commandes pour la reprendre.',
  );
  _retourListe(context, role);
}

/// « ✓ Valider » (`cmd-valider`) : contrôles, puis la commande est ajoutée au suivi de livraison.
void validerCommande(BuildContext context, WidgetRef ref) {
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

  final store = ref.read(crmProvider.notifier);
  final num = store.prochainIdCommande;
  final total = eurD(cmd.total);
  final role = ref.read(roleActifProvider);
  store.ajouterCommande(
    Commande(
      src: 'Appli',
      par: role.profil.nom,
      id: num,
      magasinId: cmd.magasinId ?? '',
      date: DemoTemps.jourCourt,
      ht: total,
      lignes: cmd.lignes.length,
      statut: StatutLivraison.pasLivree,
      eta: cmd.pas
          ? 'à partir du ${dateFr(cmd.dateMin)}'
          : DemoTemps.livraisonPrevue,
      pasAvant: cmd.pas ? cmd.dateMin : null,
      motifPas: cmd.pas ? motifFinal(cmd.motifPas, cmd.motifAutre) : null,
      note: cmd.note,
      colis: math.max(1, (cmd.nbArticles / 12).ceil()),
      evenements: [
        EvenementTransport('Commande reçue', DemoTemps.maintenantCourt),
      ],
    ),
  );
  if (cmd.deAttente != null) {
    ref.read(attenteProvider.notifier).retirer(cmd.deAttente!);
  }
  final visiteId = cmd.depuisVisite;
  final visiteExiste =
      visiteId != null &&
      ref.read(crmProvider).visites.any((v) => v.id == visiteId);
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
  ref.read(commandeEnCoursProvider.notifier).terminer();
  AppToast.show(
    context,
    'Commande $num enregistrée'
    '${cmd.pas ? ' · livraison à partir du ${dateFr(cmd.dateMin)}' : ''}. '
    'Envoi dès que le réseau le permet.',
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
